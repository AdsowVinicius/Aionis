# frozen_string_literal: true

require "json"
require "uri"
require "net/http"

module Aionis
  module Integrations
    module Ai
      # Provedor de IA via Anthropic Claude (Messages API).
      #
      # Usado APENAS como fallback do motor de classificação (CLAUDE.md §4:
      # "IA barata para revisar/classificar"). Modelo padrão: Claude Haiku 4.5
      # (rápido e barato), configurável por ENV. O restante do app não conhece a
      # Anthropic — fala só com Aionis::Integrations.ai. Cliente HTTP injetável.
      #
      # Ativação: AI_PROVIDER=anthropic + AI_API_KEY (nenhuma credencial fixa).
      class AnthropicProvider < Base
        HttpResponse = Struct.new(:code, :body)
        ENDPOINT     = "https://api.anthropic.com/v1/messages"
        API_VERSION  = "2023-06-01"

        # Persona do assistente de classificação financeira do Aionis.
        PERSONA = <<~PROMPT.freeze
          Você é o assistente de classificação financeira do Aionis, um SaaS para
          CPF, MEI e pequenas empresas no Brasil. Sua função é sugerir a categoria
          de um lançamento financeiro a partir da descrição, valor, fornecedor e
          texto do comprovante. Seja objetivo e conservador: se não tiver certeza,
          use confiança baixa. Responda SOMENTE com um JSON válido, sem comentários,
          no formato:
          {"category_id": <id da categoria ou null>, "confidence": <0-100>, "reasons": ["motivo"]}
          Escolha category_id apenas entre as categorias fornecidas.
        PROMPT

        def configured?
          api_key.present?
        end

        def classify(context:)
          return unavailable("IA não configurada") unless configured?

          prompt   = build_prompt(context)
          started  = monotonic
          response = post(system: PERSONA, user: prompt)
          elapsed  = ((monotonic - started) * 1000).round

          build_result(response, prompt, elapsed)
        rescue => e
          Result.error(provider: provider_key, message: "Falha na IA: #{e.message}")
        end

        def review(context:)   = classify(context: context)
        def complete(prompt:, **_options)
          return unavailable("IA não configurada") unless configured?

          started  = monotonic
          response = post(system: nil, user: prompt.to_s)
          elapsed  = ((monotonic - started) * 1000).round
          json     = parse(response.body)
          Result.ok(provider: provider_key, data: {
            "text"     => text_of(json),
            "usage"    => usage_of(json, elapsed)
          })
        end

        private

        def build_result(response, prompt, elapsed_ms)
          return failure(response) unless ok?(response)

          json    = parse(response.body)
          content = text_of(json)
          parsed  = extract_json(content)

          Result.ok(provider: provider_key, data: {
            "category_id" => parsed["category_id"],
            "confidence"  => parsed["confidence"].to_i.clamp(0, 100),
            "reasons"     => Array(parsed["reasons"]).map(&:to_s),
            "prompt"      => prompt,
            "response"    => content,
            "model"       => json["model"] || model,
            "usage"       => usage_of(json, elapsed_ms)
          })
        end

        def build_prompt(context)
          categories = Array(context[:categories]).map { |c| "#{c[:id]}: #{c[:name]}" }.join("\n")
          <<~TXT
            Categorias disponíveis (id: nome):
            #{categories.presence || '(nenhuma)'}

            Lançamento:
            - Natureza: #{context[:kind]}
            - Descrição: #{context[:description]}
            - Valor (centavos): #{context[:amount_cents]}
            - CPF/CNPJ: #{context[:tax_id].presence || 'não informado'}
            - Texto do comprovante (OCR): #{context[:text].to_s[0, 1500]}

            Retorne o JSON de classificação.
          TXT
        end

        # --- HTTP ---

        def post(system:, user:)
          body = {
            model:      model,
            max_tokens: max_tokens,
            messages:   [{ role: "user", content: user }]
          }
          body[:system] = system if system.present?

          headers = {
            "content-type"      => "application/json",
            "x-api-key"         => api_key,
            "anthropic-version" => API_VERSION
          }
          http.call(:post, ENDPOINT, headers, body.to_json)
        end

        def http
          settings[:http] || method(:net_http)
        end

        def net_http(method, url, headers, body)
          uri = URI(url)
          req = Net::HTTP::Post.new(uri)
          headers.each { |k, v| req[k] = v }
          req.body = body
          res = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                                read_timeout: timeout, open_timeout: timeout) { |h| h.request(req) }
          HttpResponse.new(res.code.to_i, res.body)
        end

        def ok?(resp) = resp && resp.code.to_i.between?(200, 299)

        def failure(resp)
          Result.error(provider: provider_key,
                       message: "Anthropic respondeu #{resp&.code}: #{resp&.body.to_s.truncate(200)}")
        end

        # --- Parsing ---

        def text_of(json)
          Array(json["content"]).find { |b| b["type"] == "text" }&.dig("text").to_s
        end

        # Extrai o primeiro objeto JSON do texto (tolera cercas de código).
        def extract_json(text)
          match = text.to_s[/\{.*\}/m]
          match ? JSON.parse(match) : {}
        rescue JSON::ParserError
          {}
        end

        def usage_of(json, elapsed_ms)
          usage = json["usage"] || {}
          input  = usage["input_tokens"].to_i
          output = usage["output_tokens"].to_i
          {
            "input_tokens"  => input,
            "output_tokens" => output,
            "cost_cents"    => cost_cents(input, output),
            "duration_ms"   => elapsed_ms,
            "model"         => json["model"] || model
          }
        end

        # Custo em centavos de dólar a partir dos preços por 1M tokens.
        def cost_cents(input, output)
          ((input / 1_000_000.0 * input_price) + (output / 1_000_000.0 * output_price)) * 100
        end

        def parse(body)
          JSON.parse(body.to_s)
        rescue JSON::ParserError
          {}
        end

        def monotonic = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        # --- Settings (ENV via integrations.yml) ---

        def api_key      = settings[:api_key].to_s
        def model        = settings[:model].presence || "claude-haiku-4-5"
        def max_tokens   = settings.fetch(:max_tokens, 400).to_i
        def timeout      = settings.fetch(:timeout, 20).to_i
        def input_price  = settings.fetch(:input_price, 1.0).to_f   # US$/1M tokens (Haiku 4.5)
        def output_price = settings.fetch(:output_price, 5.0).to_f
      end
    end
  end
end
