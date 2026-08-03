# frozen_string_literal: true

require "json"
require "uri"
require "net/http"

module Aionis
  module Integrations
    module Ai
      # Provedor de IA via Groq Cloud (API compatível com OpenAI Chat Completions).
      #
      # Serve aos dois usos de IA do Aionis, sem que o app saiba da troca:
      #   * fallback de classificação (Ai::Classifier) — CLAUDE.md §4
      #   * Agente Financeiro com tool calling (Agent::Conversation)
      #
      # O contrato interno do Aionis é o formato da Messages API da Anthropic
      # (blocos text/tool_use, tools com input_schema). Este provider TRADUZ nos
      # dois sentidos: Anthropic -> OpenAI ao enviar, OpenAI -> Anthropic ao
      # receber. Assim Conversation/Toolbox/Classifier não mudam uma linha.
      #
      # Ativação: AI_PROVIDER=groq + AI_API_KEY (chave gsk_...). Nenhuma
      # credencial fixa no código (CLAUDE.md §9). Cliente HTTP injetável.
      class GroqProvider < Base
        DEFAULT_BASE_URL = "https://api.groq.com/openai/v1"
        # Modelo com suporte a tool calling; troque por ENV (AI_MODEL/AGENT_MODEL).
        DEFAULT_MODEL    = "llama-3.3-70b-versatile"

        # finish_reason (OpenAI) -> stop_reason (contrato interno/Anthropic).
        STOP_REASONS = {
          "tool_calls"    => "tool_use",
          "function_call" => "tool_use",
          "stop"          => "end_turn",
          "length"        => "max_tokens"
        }.freeze

        def configured?
          api_key.present?
        end

        def classify(context:)
          return unavailable("IA não configurada") unless configured?

          prompt   = build_prompt(context)
          started  = monotonic
          response = post_raw(
            model:      model,
            max_tokens: max_tokens,
            messages:   [
              { role: "system", content: PERSONA },
              { role: "user",   content: prompt }
            ]
          )
          elapsed = ((monotonic - started) * 1000).round

          build_result(response, prompt, elapsed)
        rescue => e
          Result.error(provider: provider_key, message: "Falha na IA: #{e.message}")
        end

        def review(context:) = classify(context: context)

        # Conversa com tool calling. Recebe mensagens/tools no formato Anthropic
        # e devolve blocos no formato Anthropic — a tradução p/ OpenAI é interna.
        def chat(messages:, system: nil, tools: [], model: nil, max_tokens: nil)
          return unavailable("IA não configurada") unless configured?

          chosen = model.presence || agent_model
          body = {
            model:      chosen,
            max_tokens: (max_tokens || agent_max_tokens).to_i,
            messages:   to_openai_messages(messages, system: system)
          }
          openai_tools = to_openai_tools(tools)
          body[:tools] = openai_tools if openai_tools.any?

          started  = monotonic
          response = post_raw(**body)
          elapsed  = ((monotonic - started) * 1000).round
          return failure(response) unless ok?(response)

          json    = parse(response.body)
          message = choice(json)
          blocks  = to_anthropic_blocks(message)

          Result.ok(provider: provider_key, data: {
            "content"     => blocks,
            "stop_reason" => stop_reason(json, blocks),
            "model"       => json["model"] || chosen,
            "usage"       => usage_of(json, elapsed)
          })
        rescue => e
          Result.error(provider: provider_key, message: "Falha na IA: #{e.message}")
        end

        def complete(prompt:, **_options)
          return unavailable("IA não configurada") unless configured?

          started  = monotonic
          response = post_raw(model: model, max_tokens: max_tokens,
                              messages: [{ role: "user", content: prompt.to_s }])
          elapsed  = ((monotonic - started) * 1000).round
          return failure(response) unless ok?(response)

          json = parse(response.body)
          Result.ok(provider: provider_key, data: {
            "text"  => text_of(json),
            "usage" => usage_of(json, elapsed)
          })
        rescue => e
          Result.error(provider: provider_key, message: "Falha na IA: #{e.message}")
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

        # --- Tradução: contrato Aionis (Anthropic) -> OpenAI ------------------

        # `system` vira a primeira mensagem; blocos tool_use viram tool_calls e
        # blocos tool_result viram mensagens de role "tool".
        def to_openai_messages(messages, system: nil)
          out = []
          out << { role: "system", content: system.to_s } if system.present?

          Array(messages).each do |raw|
            msg     = raw.respond_to?(:symbolize_keys) ? raw.symbolize_keys : raw
            role    = msg[:role].to_s
            content = msg[:content]

            if content.is_a?(Array)
              out.concat(translate_blocks(role, content.map { |b| stringify(b) }))
            else
              out << { role: role, content: content.to_s }
            end
          end

          out
        end

        def translate_blocks(role, blocks)
          results = blocks.select { |b| b["type"] == "tool_result" }
          texts   = blocks.select { |b| b["type"] == "text" }.map { |b| b["text"].to_s }

          # Retorno das tools: cada tool_result é uma mensagem role "tool".
          if results.any?
            msgs = results.map do |b|
              { role: "tool", tool_call_id: b["tool_use_id"].to_s, content: b["content"].to_s }
            end
            msgs << { role: role, content: texts.join("\n") } if texts.any?
            return msgs
          end

          calls = blocks.select { |b| b["type"] == "tool_use" }.map do |b|
            {
              id:       b["id"].to_s,
              type:     "function",
              function: { name: b["name"].to_s, arguments: JSON.generate(b["input"] || {}) }
            }
          end

          message = { role: role, content: texts.join("\n").presence }
          message[:tool_calls] = calls if calls.any?
          [message]
        end

        # Tools no formato Anthropic ({name, description, input_schema}) viram
        # funções OpenAI ({type: "function", function: {..., parameters}}).
        def to_openai_tools(tools)
          Array(tools).map do |raw|
            tool = raw.respond_to?(:symbolize_keys) ? raw.symbolize_keys : raw
            {
              type:     "function",
              function: {
                name:        tool[:name].to_s,
                description: tool[:description].to_s,
                parameters:  tool[:input_schema] || { "type" => "object", "properties" => {} }
              }
            }
          end
        end

        # --- Tradução: OpenAI -> contrato Aionis (Anthropic) ------------------

        def to_anthropic_blocks(message)
          blocks = []
          text   = message["content"].to_s
          blocks << { "type" => "text", "text" => text } if text.present?

          Array(message["tool_calls"]).each do |call|
            fn = call["function"] || {}
            blocks << {
              "type"  => "tool_use",
              "id"    => call["id"].to_s,
              "name"  => fn["name"].to_s,
              "input" => extract_json(fn["arguments"])
            }
          end

          blocks
        end

        # Alguns modelos devolvem finish_reason "stop" mesmo pedindo tool:
        # a presença de tool_use manda no contrato interno.
        def stop_reason(json, blocks)
          return "tool_use" if blocks.any? { |b| b["type"] == "tool_use" }

          finish = Array(json["choices"]).first&.dig("finish_reason").to_s
          STOP_REASONS.fetch(finish, "end_turn")
        end

        def choice(json)  = Array(json["choices"]).first&.dig("message") || {}
        def text_of(json) = choice(json)["content"].to_s

        def usage_of(json, elapsed_ms)
          usage  = json["usage"] || {}
          input  = usage["prompt_tokens"].to_i
          output = usage["completion_tokens"].to_i
          {
            "input_tokens"  => input,
            "output_tokens" => output,
            "cost_cents"    => cost_cents(input, output),
            "duration_ms"   => elapsed_ms,
            "model"         => json["model"] || model
          }
        end

        # --- HTTP -------------------------------------------------------------

        def post_raw(**body)
          headers = {
            "content-type"  => "application/json",
            "authorization" => "Bearer #{api_key}"
          }
          http.call(:post, endpoint, headers, body.compact.to_json)
        end

        def failure(resp)
          Result.error(provider: provider_key,
                       message: "Groq respondeu #{resp&.code}: #{resp&.body.to_s.truncate(200)}")
        end

        def stringify(block) = block.respond_to?(:stringify_keys) ? block.stringify_keys : block

        # --- Settings (ENV via integrations.yml) ------------------------------

        def api_key  = settings[:api_key].to_s
        def base_url = (settings[:base_url].presence || DEFAULT_BASE_URL).to_s.chomp("/")
        def endpoint = "#{base_url}/chat/completions"

        def model            = settings[:model].presence || DEFAULT_MODEL
        def max_tokens       = settings.fetch(:max_tokens, 400).to_i
        def agent_model      = settings[:agent_model].presence || model
        def agent_max_tokens = settings.fetch(:agent_max_tokens, 1024).to_i
        # Preços US$/1M tokens do llama-3.3-70b-versatile (ENV sobrescreve).
        def default_input_price  = 0.59
        def default_output_price = 0.79
      end
    end
  end
end
