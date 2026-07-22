# frozen_string_literal: true

module Aionis
  module Integrations
    module Ai
      # Contrato de um provedor de IA (ex.: Anthropic Claude). Usada como camada
      # de REVISÃO/classificação, não como primeira camada (CLAUDE.md seção 3/4).
      # Consumidor natural: Aionis::ClassificationEngine como fallback quando
      # regras e histórico não bastam. NÃO implementado nesta etapa.
      class Base < BaseProvider
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
      end
    end
  end
end
