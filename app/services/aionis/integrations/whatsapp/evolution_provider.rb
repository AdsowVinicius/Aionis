# frozen_string_literal: true

require "json"
require "uri"
require "net/http"
require "base64"

module Aionis
  module Integrations
    module Whatsapp
      # Provedor de WhatsApp via Evolution API (não oficial, self-hosted).
      #
      # Traduz o contrato genérico (Whatsapp::Base) para as rotas REST da
      # Evolution. NENHUM outro ponto do app conhece a Evolution — todos falam
      # apenas com Aionis::Integrations.whatsapp.
      #
      # Credenciais globais (base_url, api_key, webhook_token) vêm de ENV via
      # config/aionis/integrations.yml. A instância e o destino são por chamada
      # (multi-canal). Cliente HTTP injetável (settings[:http]) para testes.
      #
      # Ativação: WHATSAPP_PROVIDER=evolution.
      class EvolutionProvider < Base
        HttpResponse = Struct.new(:code, :body)

        def configured?
          base_url.present? && api_key.present?
        end

        # --- Envio ---

        def send_text(to:, body:, instance: nil)
          return unavailable("Evolution não configurado") unless configured?

          resp = post("message/sendText/#{inst(instance)}", { number: number(to), text: body })
          on_response(resp) do |json|
            Result.ok(provider: provider_key, data: { "message_id" => message_id(json) })
          end
        end

        def send_template(to:, name:, locale: "pt_BR", variables: [], instance: nil)
          # Evolution não usa templates aprovados; envia como texto.
          send_text(to: to, body: variables.join(" "), instance: instance)
        end

        # --- Recebimento ---

        def parse_inbound(payload)
          payload = deep_stringify(payload)
          return ignored("evento ignorado") unless payload["event"].to_s == "messages.upsert"

          data = payload["data"] || {}
          key  = data["key"] || {}
          return ignored("mensagem própria") if key["fromMe"]

          kind, text, media = extract_message(data["message"] || {}, key)

          Result.ok(provider: provider_key, data: {
            "instance"      => payload["instance"],
            "wa_message_id" => key["id"],
            "from"          => number(key["remoteJid"]),
            "from_me"       => !!key["fromMe"],
            "type"          => kind,
            "text"          => text,
            "media"         => media,
            "push_name"     => data["pushName"],
            "received_at"   => received_at(data)
          })
        end

        def download_media(media, instance: nil)
          media = deep_stringify(media)
          bytes = decode_base64(media["base64"])

          if bytes.blank? && configured?
            resp  = post("chat/getBase64FromMediaMessage/#{inst(instance)}",
                         { message: { key: media["key"] } })
            return failure(resp) unless ok?(resp)
            bytes = decode_base64(parse_json(resp.body)["base64"])
          end

          return unavailable("Mídia sem conteúdo") if bytes.blank?

          Result.ok(provider: provider_key, data: {
            "bytes"    => bytes,
            "mimetype" => media["mimetype"],
            "filename" => media["filename"].presence || default_filename(media)
          })
        end

        # --- Webhook auth ---

        def verify_webhook(token:, mode: nil, challenge: nil)
          expected = webhook_token
          return unavailable("Webhook token não configurado") if expected.blank?

          if token.present? && ActiveSupport::SecurityUtils.secure_compare(token.to_s, expected)
            Result.ok(provider: provider_key, data: { "challenge" => challenge })
          else
            Result.error(provider: provider_key, message: "Token de webhook inválido")
          end
        end

        private

        # --- HTTP ---

        def post(path, payload)
          url     = "#{base_url.chomp('/')}/#{path}"
          headers = { "Content-Type" => "application/json", "apikey" => api_key }
          http.call(:post, url, headers, payload.to_json)
        end

        # Cliente HTTP: injetado (testes) ou Net::HTTP.
        def http
          settings[:http] || method(:net_http)
        end

        def net_http(method, url, headers, body)
          uri = URI(url)
          req = (method == :get ? Net::HTTP::Get : Net::HTTP::Post).new(uri)
          headers.each { |k, v| req[k] = v }
          req.body = body if body
          res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                read_timeout: timeout, open_timeout: timeout) { |h| h.request(req) }
          HttpResponse.new(res.code.to_i, res.body)
        end

        def on_response(resp)
          return failure(resp) unless ok?(resp)
          yield parse_json(resp.body)
        end

        def ok?(resp)  = resp && resp.code.to_i.between?(200, 299)
        def failure(resp)
          Result.error(provider: provider_key,
                       message: "Evolution respondeu #{resp&.code}: #{resp&.body.to_s.truncate(200)}")
        end

        # --- Parsing de mensagem ---

        def extract_message(message, key)
          if message["conversation"].present?
            ["text", message["conversation"], nil]
          elsif (ext = message["extendedTextMessage"])
            ["text", ext["text"], nil]
          elsif (img = message["imageMessage"])
            ["image", img["caption"], media_of(img, message, key, "image")]
          elsif (doc = message["documentMessage"])
            ["document", doc["caption"] || doc["title"], media_of(doc, message, key, "document", doc["fileName"])]
          else
            ["other", nil, nil]
          end
        end

        def media_of(node, message, key, type, filename = nil)
          {
            "mimetype" => node["mimetype"],
            "filename" => filename,
            "base64"   => node["base64"].presence || message["base64"].presence,
            "key"      => key,
            "type"     => type
          }
        end

        def default_filename(media)
          ext = Rack::Mime::MIME_TYPES.invert[media["mimetype"]] || ""
          "whatsapp_#{Time.current.to_i}#{ext}"
        end

        # --- Helpers ---

        def message_id(json)
          json.dig("key", "id") || json["messageId"] || json["id"]
        end

        def received_at(data)
          ts = data["messageTimestamp"]
          ts.present? ? Time.at(ts.to_i).utc.iso8601 : Time.current.utc.iso8601
        rescue StandardError
          Time.current.utc.iso8601
        end

        def number(jid)
          jid.to_s.split("@").first.to_s.gsub(/\D/, "").presence
        end

        def decode_base64(str)
          return nil if str.blank?
          Base64.decode64(str)
        rescue StandardError
          nil
        end

        def parse_json(body)
          JSON.parse(body.to_s)
        rescue JSON::ParserError
          {}
        end

        def deep_stringify(obj)
          obj.respond_to?(:deep_stringify_keys) ? obj.deep_stringify_keys : obj
        end

        def ignored(message)
          Result.ok(provider: provider_key, data: { "type" => "ignored", "reason" => message })
        end

        def inst(instance)   = (instance.presence || settings[:instance]).to_s
        def base_url         = settings[:base_url].to_s
        def api_key          = settings[:api_key].to_s
        def webhook_token    = settings[:webhook_token].to_s
        def timeout          = settings.fetch(:timeout, 15).to_i
      end
    end
  end
end
