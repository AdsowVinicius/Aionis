# frozen_string_literal: true

require "json"
require "uri"
require "net/http"
require "bigdecimal"

module Aionis
  module Integrations
    module OpenFinance
      # Provedor de Open Finance via Pluggy (https://pluggy.ai).
      #
      # Traduz o contrato genérico (OpenFinance::Base) para a API da Pluggy. O
      # restante do app NUNCA conhece a Pluggy — fala apenas com
      # Aionis::Integrations.open_finance. Credenciais só via ENV
      # (config/aionis/integrations.yml). Cliente HTTP injetável para testes.
      #
      # Mapeamento: consent_id == itemId da Pluggy.
      # Ativação: OPEN_FINANCE_PROVIDER=pluggy.
      class PluggyProvider < Base
        HttpResponse = Struct.new(:code, :body)

        def configured?
          client_id.present? && client_secret.present?
        end

        # Cria um connect token (a "conexão"/item é criada pelo widget da Pluggy).
        def create_consent(workspace_id:, redirect_url:)
          return unavailable("Pluggy não configurado") unless configured?

          resp = request(:post, "connect_token", body: {})
          on_ok(resp) do |json|
            token = json["accessToken"]
            Result.ok(provider: provider_key, data: {
              "connect_token" => token,
              "redirect_url"  => "#{connect_url}?connect_token=#{token}",
              "expires_at"    => nil
            })
          end
        end

        def fetch_accounts(consent_id:)
          return unavailable("Pluggy não configurado") unless configured?

          resp = request(:get, "accounts", query: { itemId: consent_id })
          on_ok(resp) do |json|
            Result.ok(provider: provider_key,
                      data: { "accounts" => Array(json["results"]).map { |a| normalize_account(a) } })
          end
        end

        def fetch_transactions(account_id:, from:, to:)
          return unavailable("Pluggy não configurado") unless configured?

          resp = request(:get, "transactions",
                         query: { accountId: account_id, from: from, to: to, pageSize: 500 })
          on_ok(resp) do |json|
            Result.ok(provider: provider_key,
                      data: { "transactions" => Array(json["results"]).map { |t| normalize_transaction(t) } })
          end
        end

        def revoke_consent(consent_id:)
          return unavailable("Pluggy não configurado") unless configured?

          resp = request(:delete, "items/#{consent_id}")
          ok?(resp) ? Result.ok(provider: provider_key, data: {}) : failure(resp)
        end

        private

        # --- HTTP + auth ---

        def request(method, path, query: {}, body: nil)
          key = api_key
          return HttpResponse.new(401, '{"message":"auth falhou"}') if key.blank?

          url     = build_url(path, query)
          headers = { "Content-Type" => "application/json", "X-API-KEY" => key }
          http.call(method, url, headers, body && body.to_json)
        end

        # Autentica e memoiza a apiKey (clientId/secret -> apiKey).
        def api_key
          return @api_key if defined?(@api_key)

          resp = http.call(:post, build_url("auth", {}),
                           { "Content-Type" => "application/json" },
                           { clientId: client_id, clientSecret: client_secret }.to_json)
          @api_key = ok?(resp) ? parse(resp.body)["apiKey"] : nil
        end

        def http
          settings[:http] || method(:net_http)
        end

        def net_http(method, url, headers, body)
          uri = URI(url)
          klass = { get: Net::HTTP::Get, post: Net::HTTP::Post, delete: Net::HTTP::Delete }.fetch(method)
          req = klass.new(uri)
          headers.each { |k, v| req[k] = v }
          req.body = body if body
          res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                read_timeout: timeout, open_timeout: timeout) { |h| h.request(req) }
          HttpResponse.new(res.code.to_i, res.body)
        end

        def build_url(path, query)
          url = "#{base_url.chomp('/')}/#{path}"
          query = query.compact
          query.any? ? "#{url}?#{URI.encode_www_form(query)}" : url
        end

        def on_ok(resp)
          ok?(resp) ? yield(parse(resp.body)) : failure(resp)
        end

        def ok?(resp) = resp && resp.code.to_i.between?(200, 299)

        def failure(resp)
          Result.error(provider: provider_key,
                       message: "Pluggy respondeu #{resp&.code}: #{resp&.body.to_s.truncate(200)}")
        end

        def parse(body)
          JSON.parse(body.to_s)
        rescue JSON::ParserError
          {}
        end

        # --- Normalização ---

        def normalize_account(a)
          {
            "external_id"   => a["id"],
            "name"          => a["name"].presence || a["marketingName"],
            "institution"   => a.dig("bankData", "name"),
            "branch"        => a.dig("bankData", "branch"),
            "number"        => a["number"],
            "kind"          => account_kind(a["type"], a["subtype"]),
            "currency"      => a["currencyCode"].presence || "BRL",
            "balance_cents" => to_cents(a["balance"])
          }
        end

        def normalize_transaction(t)
          {
            "external_id"  => t["id"],
            "amount_cents" => to_cents(t["amount"]).abs,
            "direction"    => (t["type"].to_s.upcase == "CREDIT" ? "credit" : "debit"),
            "date"         => parse_date(t["date"]),
            "description"  => t["description"].presence || t["descriptionRaw"],
            "raw"          => t
          }
        end

        def account_kind(type, subtype)
          case subtype.to_s.upcase
          when "CHECKING_ACCOUNT" then "checking"
          when "SAVINGS_ACCOUNT"  then "savings"
          else type.to_s.upcase == "CREDIT" ? "credit" : "other"
          end
        end

        def to_cents(value)
          return nil if value.nil?
          (BigDecimal(value.to_s) * 100).round.to_i
        rescue ArgumentError
          nil
        end

        def parse_date(str)
          str.present? ? Date.parse(str).iso8601 : nil
        rescue ArgumentError
          nil
        end

        # --- Settings (ENV via integrations.yml) ---

        def base_url      = settings[:base_url].presence || "https://api.pluggy.ai"
        def connect_url   = settings[:connect_url].presence || "https://connect.pluggy.ai"
        def client_id     = settings[:client_id].to_s
        def client_secret = settings[:client_secret].to_s
        def timeout       = settings.fetch(:timeout, 20).to_i
      end
    end
  end
end
