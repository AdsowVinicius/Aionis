# frozen_string_literal: true

require "json"
require "uri"
require "net/http"

module Aionis
  module Integrations
    module Ai
      # Contrato de um provedor de IA (ex.: Anthropic Claude, Groq). Usada como
      # camada de REVISÃO/classificação, não como primeira camada (CLAUDE.md §3/4).
      # Consumidor natural: Aionis::ClassificationEngine como fallback quando
      # regras e histórico não bastam.
      #
      # O FORMATO DE TROCA é sempre o da Messages API da Anthropic (blocos
      # text/tool_use, tools com input_schema) — é o contrato interno do Aionis.
      # Provedores com outra API (Groq/OpenAI) traduzem nos dois sentidos, para
      # que Agent::Conversation e Ai::Classifier nunca mudem ao trocar de IA.
      class Base < BaseProvider
        # Persona do assistente de classificação financeira do Aionis.
        # Compartilhada por todos os provedores: trocar de IA não pode mudar o
        # comportamento do fallback de classificação.
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

        # Sugere classificação para um lançamento a partir de contexto.
        # @param context [Hash] { description:, amount_cents:, counterparty:, tax_id: }
        # @return [Result] data: { category:, confidence:, reasons: [] }
        def classify(context:)
          not_implemented!(:classify)
        end

        # Revisa/valida uma extração ou sugestão existente.
        # @return [Result] data: { approved:, corrections:, confidence: }
        def review(context:)
          not_implemented!(:review)
        end

        # Completação genérica de texto (uso pontual/fallback).
        # @return [Result] data: { text: }
        def complete(prompt:, **options)
          not_implemented!(:complete)
        end

        # Conversa com tool calling (Agente Financeiro). `messages` segue o
        # formato da Messages API ({role:, content:}); `tools` são definições
        # JSON Schema. O provider NUNCA executa tools — apenas devolve os
        # blocos (tool_use/text) para o orquestrador decidir.
        # @return [Result] data: { content: [], stop_reason:, model:, usage: }
        def chat(messages:, system: nil, tools: [], model: nil, max_tokens: nil)
          not_implemented!(:chat)
        end

        private

        # --- Prompt de classificação (idêntico em todos os provedores) --------

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

        # Extrai o primeiro objeto JSON do texto (tolera cercas de código).
        def extract_json(text)
          match = text.to_s[/\{.*\}/m]
          match ? JSON.parse(match) : {}
        rescue JSON::ParserError
          {}
        end

        def parse(body)
          JSON.parse(body.to_s)
        rescue JSON::ParserError
          {}
        end

        # --- Custo/uso --------------------------------------------------------

        # Custo em centavos de dólar a partir dos preços por 1M tokens.
        def cost_cents(input, output)
          ((input / 1_000_000.0 * input_price) + (output / 1_000_000.0 * output_price)) * 100
        end

        # Preços US$/1M tokens. Cada provedor define seu default (modelos e
        # tabelas de preço são diferentes); ENV sobrescreve quando presente.
        def input_price  = (settings[:input_price].presence || default_input_price).to_f
        def output_price = (settings[:output_price].presence || default_output_price).to_f

        def default_input_price  = 1.0
        def default_output_price = 5.0

        def monotonic = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        # --- HTTP (cliente injetável para testes) -----------------------------

        HttpResponse = Struct.new(:code, :body)

        def http
          settings[:http] || method(:net_http)
        end

        def net_http(_method, url, headers, body)
          uri = URI(url)
          req = Net::HTTP::Post.new(uri)
          headers.each { |k, v| req[k] = v }
          req.body = body
          res = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                                read_timeout: timeout, open_timeout: timeout) { |h| h.request(req) }
          HttpResponse.new(res.code.to_i, res.body)
        end

        def ok?(resp) = resp && resp.code.to_i.between?(200, 299)

        def timeout = settings.fetch(:timeout, 20).to_i
      end
    end
  end
end
