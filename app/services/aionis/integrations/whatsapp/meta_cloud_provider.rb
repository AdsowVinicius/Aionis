# frozen_string_literal: true

require "json"
require "uri"
require "net/http"
require "openssl"

module Aionis
  module Integrations
    module Whatsapp
      # Provedor oficial WhatsApp Cloud API (Meta / Graph API).
      #
      # Traduz o contrato genérico (Whatsapp::Base) para o Graph API. NENHUM
      # outro ponto do app conhece a Meta — todos falam apenas com
      # Aionis::Integrations.whatsapp. Multi-tenant: as credenciais do workspace
      # (access_token, phone_number_id) chegam por chamada em `credentials:`; os
      # segredos de app (app_secret, verify_token) e a versão do Graph vêm de ENV
      # via config/aionis/integrations.yml (nunca hardcoded).
      #
      # Ativação: WHATSAPP_PROVIDER=meta_cloud. Cliente HTTP injetável em testes.
      class MetaCloudProvider < Base
        HttpResponse = Struct.new(:code, :body)

        def configured?
          app_secret.present?
        end

        # --- Envio ---

        def send_text(to:, body:, instance: nil, credentials: nil)
          send_message(to: to, type: "text", fragment: { text: { body: body } }, credentials: credentials)
        end

        def send_template(to:, name:, locale: "pt_BR", variables: [], instance: nil, credentials: nil)
          components = variables.any? ? [{ type: "body", parameters: variables.map { |v| { type: "text", text: v } } }] : []
          send_message(to: to, type: "template", credentials: credentials,
                       fragment: { template: { name: name, language: { code: locale }, components: components } })
        end

        def send_document(to:, media:, caption: nil, instance: nil, credentials: nil)
          send_media(to: to, type: "document", media: media, caption: caption, credentials: credentials)
        end

        def send_image(to:, media:, caption: nil, instance: nil, credentials: nil)
          send_media(to: to, type: "image", media: media, caption: caption, credentials: credentials)
        end

        def send_audio(to:, media:, instance: nil, credentials: nil)
          send_media(to: to, type: "audio", media: media, credentials: credentials)
        end

        def mark_as_read(message_id:, instance: nil, credentials: nil)
          cred = creds(credentials)
          return unavailable("Sem access_token/phone_number_id") unless cred[:access_token].present? && cred[:phone_number_id].present?

          resp = post_messages(cred, { messaging_product: "whatsapp", status: "read", message_id: message_id })
          ok?(resp) ? Result.ok(provider: provider_key, data: {}) : failure(resp)
        end

        # --- Recebimento ---

        def parse_inbound(payload)
          value = payload.dig("entry", 0, "changes", 0, "value") || {}
          phone_number_id = value.dig("metadata", "phone_number_id")

          if (message = Array(value["messages"]).first)
            parse_message(message, value, phone_number_id)
          elsif (status = Array(value["statuses"]).first)
            Result.ok(provider: provider_key, data: {
              "event" => "status", "wa_message_id" => status["id"], "status" => status["status"],
              "phone_number_id" => phone_number_id
            })
          else
            Result.ok(provider: provider_key, data: { "event" => "ignored" })
          end
        rescue => e
          Result.error(provider: provider_key, message: "Payload inválido: #{e.message}")
        end

        # Baixa a mídia em duas etapas: resolve a URL pelo id e baixa o binário.
        def download_media(media, instance: nil, credentials: nil)
          cred = creds(credentials)
          media = media.to_h
          media_id = media["id"] || media[:id]
          return unavailable("Mídia sem id") if media_id.blank?
          return unavailable("Sem access_token") if cred[:access_token].blank?

          meta = get("#{base_url}/#{media_id}", cred[:access_token])
          return failure(meta) unless ok?(meta)
          url = parse_json(meta.body)["url"]
          return unavailable("URL de mídia ausente") if url.blank?

          binary = get(url, cred[:access_token])
          return failure(binary) unless ok?(binary)

          Result.ok(provider: provider_key, data: {
            "bytes"    => binary.body,
            "mimetype" => media["mimetype"] || media["mime_type"],
            "filename" => media["filename"].presence || "whatsapp_#{media_id}",
            "url"      => url
          })
        end

        # --- Webhook ---

        def verify_webhook(token: nil, mode: nil, challenge: nil)
          if mode.to_s == "subscribe" && token.present? &&
             ActiveSupport::SecurityUtils.secure_compare(token.to_s, verify_token)
            Result.ok(provider: provider_key, data: { "challenge" => challenge })
          else
            Result.error(provider: provider_key, message: "Verificação de webhook inválida")
          end
        end

        def verify_signature(raw_body:, signature:)
          return unavailable("App secret não configurado") if app_secret.blank?
          return Result.error(provider: provider_key, message: "Assinatura ausente") if signature.blank?

          expected = "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", app_secret, raw_body.to_s)
          if ActiveSupport::SecurityUtils.secure_compare(signature.to_s, expected)
            Result.ok(provider: provider_key, data: {})
          else
            Result.error(provider: provider_key, message: "Assinatura HMAC inválida")
          end
        end

        private

        # --- Envio (helpers) ---

        def send_message(to:, type:, fragment:, credentials:)
          cred = creds(credentials)
          return unavailable("Sem access_token/phone_number_id") unless cred[:access_token].present? && cred[:phone_number_id].present?

          body = { messaging_product: "whatsapp", to: to.to_s, type: type }.merge(fragment)
          resp = post_messages(cred, body)
          on_ok(resp) do |json|
            Result.ok(provider: provider_key, data: { "message_id" => json.dig("messages", 0, "id") })
          end
        end

        def send_media(to:, type:, media:, caption: nil, credentials:)
          node = media.is_a?(Hash) ? media : { link: media.to_s }
          node = node.merge(caption: caption) if caption.present? && %w[document image].include?(type)
          send_message(to: to, type: type, fragment: { type => node }, credentials: credentials)
        end

        def post_messages(cred, body)
          url     = "#{base_url}/#{cred[:phone_number_id]}/messages"
          headers = { "Content-Type" => "application/json", "Authorization" => "Bearer #{cred[:access_token]}" }
          http.call(:post, url, headers, body.to_json)
        end

        # --- Parsing ---

        def parse_message(message, value, phone_number_id)
          type = message["type"].to_s
          name = value.dig("contacts", 0, "profile", "name")
          media = extract_media(message, type)

          Result.ok(provider: provider_key, data: {
            "event"           => "message",
            "wa_message_id"   => message["id"],
            "from"            => message["from"],
            "from_me"         => false,
            "push_name"       => name,
            "type"            => normalize_type(type),
            "text"            => message.dig("text", "body"),
            "media"           => media,
            "phone_number_id" => phone_number_id,
            "received_at"     => timestamp(message["timestamp"])
          })
        end

        def extract_media(message, type)
          node = message[type]
          return nil unless node.is_a?(Hash) && %w[document image audio video].include?(type)

          {
            "id"       => node["id"],
            "mimetype" => node["mime_type"],
            "filename" => node["filename"]
          }
        end

        def normalize_type(type)
          return type if %w[text document image audio].include?(type)
          "other"
        end

        # --- HTTP ---

        def http
          settings[:http] || method(:net_http)
        end

        def get(url, token)
          http.call(:get, url, { "Authorization" => "Bearer #{token}" }, nil)
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

        def on_ok(resp)
          ok?(resp) ? yield(parse_json(resp.body)) : failure(resp)
        end

        def ok?(resp) = resp && resp.code.to_i.between?(200, 299)

        def failure(resp)
          retryable = resp && [429, 500, 502, 503].include?(resp.code.to_i)
          Result.new(success: false, provider: provider_key, status: retryable ? :pending : :error,
                     data: { "retryable" => retryable, "http_status" => resp&.code },
                     message: "Meta respondeu #{resp&.code}: #{resp&.body.to_s.truncate(200)}")
        end

        def parse_json(body)
          JSON.parse(body.to_s)
        rescue JSON::ParserError
          {}
        end

        def timestamp(ts)
          ts.present? ? Time.at(ts.to_i).utc.iso8601 : Time.current.utc.iso8601
        rescue StandardError
          Time.current.utc.iso8601
        end

        # Credenciais do número global (ENV via settings). Aceita override por
        # chamada (credentials:) para compatibilidade com canais legados.
        def creds(credentials)
          provided = (credentials || {}).symbolize_keys
          {
            access_token:    provided[:access_token].presence    || settings[:access_token].to_s.presence,
            phone_number_id: provided[:phone_number_id].presence || settings[:phone_number_id].to_s.presence
          }
        end

        # --- Settings (ENV via integrations.yml) — nada hardcoded ---

        def base_url      = "#{host}/#{graph_version}"
        def host          = settings[:base_url].presence || "https://graph.facebook.com"
        def graph_version = settings[:graph_version].to_s
        def app_secret    = settings[:app_secret].to_s
        def verify_token  = settings[:verify_token].to_s
        def timeout       = settings.fetch(:timeout, 20).to_i
      end
    end
  end
end
