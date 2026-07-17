# frozen_string_literal: true

module Aionis
  module Ai
    # Fallback de IA do motor de classificação. Só é acionado pelo
    # ClassificationEngine quando regras e histórico não bastam (ver gate lá).
    #
    # Monta o contexto (categorias do workspace + dados do lançamento), chama
    # Aionis::Integrations.ai (o app não conhece o provedor concreto), registra
    # tudo em AiInteraction (prompt, resposta, custo, tokens, tempo, provider,
    # confidence) e em AuditLog, e devolve uma sugestão no mesmo contrato do
    # motor (ClassificationEngine::Suggestion) ou nil.
    class Classifier
      def self.call(context:) = new(context).call

      def initialize(context)
        @context   = context
        @workspace = context[:workspace]
      end

      def call
        return nil unless provider.respond_to?(:configured?) && provider.configured?

        result = provider.classify(context: ai_context)
        return nil unless result.success?

        category = resolve_category(result.data["category_id"])
        record(result, category)
        build_suggestion(result, category)
      rescue => e
        Rails.logger.error("[Ai::Classifier] #{e.class}: #{e.message}")
        nil
      end

      private

      def provider = Aionis::Integrations.ai

      def ai_context
        {
          categories:   categories.map { |c| { id: c.id, name: c.name } },
          description:  @context[:description],
          kind:         @context[:kind],
          amount_cents: @context[:amount_cents],
          tax_id:       @context[:tax_id],
          text:         @context[:text]
        }
      end

      def categories
        @categories ||= Category.for_workspace(@workspace).order(:name).to_a
      end

      def resolve_category(category_id)
        return nil if category_id.blank?
        categories.find { |c| c.id.to_i == category_id.to_i }
      end

      def build_suggestion(result, category)
        return nil if category.nil?

        Aionis::ClassificationEngine::Suggestion.new(
          category_id:  category.id,
          category:     category,
          cost_type:    category.cost_type,
          essentiality: category.essentiality,
          scope:        nil,
          recurrence:   nil,
          cost_center:  nil,
          confidence:   result.data["confidence"].to_i,
          source:       "ai",
          reasons:      ai_reasons(result)
        )
      end

      def ai_reasons(result)
        reasons = Array(result.data["reasons"]).reject(&:blank?)
        ["Sugestão da IA (#{result.provider})"] + reasons
      end

      def record(result, category)
        usage = result.data["usage"] || {}
        interaction = AiInteraction.create!(
          workspace:             @workspace,
          financial_transaction: @context[:financial_transaction],
          document:              @context[:document],
          kind:                  "classification",
          provider:              result.provider,
          model:                 usage["model"] || result.data["model"],
          prompt:                result.data["prompt"],
          response:              result.data["response"],
          tokens_input:          usage["input_tokens"].to_i,
          tokens_output:         usage["output_tokens"].to_i,
          cost_cents:            usage["cost_cents"].to_f,
          duration_ms:           usage["duration_ms"],
          confidence:            result.data["confidence"],
          metadata:              { category_id: category&.id }
        )

        AuditLog.log(
          action: "ai", origin: "ai",
          workspace: @workspace, provider: result.provider,
          financial_transaction: @context[:financial_transaction],
          document: @context[:document],
          confidence: result.data["confidence"],
          reason: "Classificação por IA (fallback)",
          metadata: {
            ai_interaction_id: interaction.id,
            tokens: interaction.total_tokens,
            cost_cents: interaction.cost_cents,
            category_id: category&.id
          }
        )
      rescue => e
        Rails.logger.error("[Ai::Classifier] falha ao registrar: #{e.message}")
      end
    end
  end
end
