# frozen_string_literal: true

module Aionis
  # Motor de Classificação Financeira — 100% interno, baseado em regras
  # configuráveis (CategoryRule) e no histórico do próprio usuário.
  #
  # Implementa a seção 8 do CLAUDE.md: sugere categoria, tipo de custo,
  # essencialidade, escopo (pessoal/empresarial), centro de custo, recorrência
  # e nível de confiança a partir de fornecedor, CPF/CNPJ, descrição e histórico.
  #
  # Ordem de precedência (CLAUDE.md seção 4/8):
  #   1. regras (workspace tem prioridade sobre global)
  #   2. histórico do fornecedor / correções anteriores do usuário
  #   3. IA apenas quando necessário (fora do MVP — deixado como fallback vazio)
  #
  # NÃO classifica automaticamente com baixa confiança: apenas sugere. Categoria
  # continua opcional enquanto o lançamento está pendente.
  #
  #   suggestion = Aionis::ClassificationEngine.for_transaction(tx).call
  #   suggestion.category_id, suggestion.confidence, suggestion.reasons, ...
  class ClassificationEngine
    # Contexto imutável extraído do lançamento (ou de atributos avulsos).
    # extra_text: texto adicional (ex.: OCR bruto) usado apenas para casar
    # palavras-chave de regras — não vira descrição do lançamento.
    Context = Struct.new(:workspace, :description, :kind, :counterparty_id, :tax_id_digits, :exclude_id, :extra_text, keyword_init: true)

    Suggestion = Struct.new(
      :category_id, :category, :cost_type, :essentiality, :scope,
      :recurrence, :cost_center, :confidence, :source, :reasons,
      keyword_init: true
    ) do
      def present?            = category_id.present? || confidence.to_i.positive?
      def auto_applicable?    = Aionis::Confidence.high?(confidence)
      def needs_confirmation? = Aionis::Confidence.medium?(confidence)
      def low_confidence?     = Aionis::Confidence.low?(confidence)
    end

    def self.for_transaction(transaction, exclude_learned: false, extra_text: nil, allow_ai: false)
      digits = transaction.counterparty&.tax_id.presence ||
               transaction.counterparty_tax_id_snapshot.presence
      new(
        workspace:       transaction.workspace,
        description:     transaction.description,
        kind:            transaction.kind,
        counterparty_id: transaction.counterparty_id,
        tax_id:          digits,
        exclude_id:      transaction.id,
        exclude_learned: exclude_learned,
        extra_text:      extra_text,
        allow_ai:        allow_ai
      )
    end

    def initialize(workspace:, description:, kind:, counterparty_id: nil, tax_id: nil, exclude_id: nil, exclude_learned: false, extra_text: nil, allow_ai: false)
      @exclude_learned = exclude_learned
      @allow_ai        = allow_ai
      @context = Context.new(
        workspace:       workspace,
        description:     description.to_s,
        kind:            kind.to_s,
        counterparty_id: counterparty_id,
        tax_id_digits:   tax_id.to_s.gsub(/\D/, "").presence,
        exclude_id:      exclude_id,
        extra_text:      extra_text.to_s
      )
    end

    def call
      rule    = best_matching_rule
      history = history_signal

      base =
        if rule
          build_from_rule(rule, history)
        elsif history
          build_from_history(history)
        else
          empty_suggestion
        end

      maybe_ai_fallback(base)
    end

    private

    # IA APENAS como fallback (CLAUDE.md §4). Nunca chama IA quando:
    #   - o Rule Engine acertou (regra casou), ou
    #   - a confiança já é superior ao limite configurado.
    def maybe_ai_fallback(base)
      return base unless @allow_ai
      return base if base.source.to_s.start_with?("rule")
      return base if base.confidence.to_i > ai_threshold

      ai = ai_fallback
      ai&.present? ? ai : base
    end

    def ai_fallback
      Aionis::Ai::Classifier.call(context: {
        workspace:   context.workspace,
        description: context.description,
        kind:        context.kind,
        tax_id:      context.tax_id_digits,
        text:        context.extra_text
      })
    rescue => e
      Rails.logger.error("[ClassificationEngine] IA fallback falhou: #{e.message}")
      nil
    end

    def ai_threshold
      ENV.fetch("AI_FALLBACK_THRESHOLD", Aionis::Confidence::LOW_MAX.to_s).to_i
    end

    attr_reader :context

    # --- Passo 1: regras ---

    def best_matching_rule
      relation   = CategoryRule.active.for_workspace(context.workspace).includes(:category)
      relation   = relation.where.not(origin: "learned") if @exclude_learned
      candidates = relation.to_a
      matches = candidates.select { |r| r.matches?(context) }
      return nil if matches.empty?

      matches.max_by do |r|
        [r.global? ? 0 : 1, r.priority.to_i, r.match_strength(context)]
      end
    end

    def build_from_rule(rule, history)
      category   = rule.category
      confidence = [rule.confidence.to_i + (rule.match_strength(context) - 1) * 5, 100].min
      reasons    = ["Regra aplicada: #{rule.name}"]
      source     = "rule"

      # Histórico do fornecedor reforça (ou diverge) da regra
      if history
        if history[:category_id] == category&.id
          confidence = [confidence + 10, 100].min
          reasons << "Histórico do fornecedor confirma esta categoria"
          source = "rule+history"
        else
          reasons << "Atenção: histórico do fornecedor aponta outra categoria"
        end
      end

      suggestion(
        category:    category,
        cost_type:   rule.cost_type.presence   || category&.cost_type,
        essentiality: rule.essentiality.presence || category&.essentiality,
        scope:       rule.scope,
        recurrence:  rule.recurrence,
        cost_center: rule.cost_center,
        confidence:  confidence,
        source:      source,
        reasons:     reasons
      )
    end

    # --- Passo 2: histórico do fornecedor ---

    # Retorna { category_id:, category:, count:, dominant:, dominance: } ou nil
    def history_signal
      return @history_signal if defined?(@history_signal)

      @history_signal =
        if context.counterparty_id.present? || context.tax_id_digits.present?
          scope = history_scope
          counts = scope.group(:category_id).count
          if counts.present?
            total     = counts.values.sum
            top_id, n = counts.max_by { |_id, c| c }
            {
              category_id: top_id,
              category:    Category.find_by(id: top_id),
              count:       total,
              dominant:    n,
              dominance:   (n.to_f / total)
            }
          end
        end
    end

    def history_scope
      rel = context.workspace.financial_transactions
                   .where.not(category_id: nil)
                   .where(status: %w[classified confirmed])
      rel = rel.where.not(id: context.exclude_id) if context.exclude_id.present?

      if context.counterparty_id.present?
        rel.where(counterparty_id: context.counterparty_id)
      else
        # Sem fornecedor vinculado: casa pelo snapshot de CPF/CNPJ (só dígitos)
        digits = context.tax_id_digits
        rel.where("regexp_replace(COALESCE(counterparty_tax_id_snapshot, ''), '\\D', '', 'g') = ?", digits)
      end
    end

    def build_from_history(history)
      category = history[:category]
      # Confiança do histórico: base + volume + dominância (teto 90)
      confidence = 50
      confidence += [history[:dominant] * 8, 30].min
      confidence += 10 if history[:dominance] >= 0.8
      confidence = [confidence, 90].min

      suggestion(
        category:    category,
        cost_type:   category&.cost_type,
        essentiality: category&.essentiality,
        scope:       nil,
        recurrence:  nil,
        cost_center: nil,
        confidence:  confidence,
        source:      "history",
        reasons:     ["Baseado em #{history[:count]} lançamento#{'s' if history[:count] != 1} anterior#{'es' if history[:count] != 1} deste fornecedor"]
      )
    end

    def empty_suggestion
      Suggestion.new(
        category_id: nil, category: nil, cost_type: nil, essentiality: nil,
        scope: nil, recurrence: nil, cost_center: nil, confidence: 0,
        source: "none", reasons: ["Sem regra ou histórico correspondente"]
      )
    end

    def suggestion(category:, cost_type:, essentiality:, scope:, recurrence:, cost_center:, confidence:, source:, reasons:)
      Suggestion.new(
        category_id:  category&.id,
        category:     category,
        cost_type:    cost_type,
        essentiality: essentiality,
        scope:        scope,
        recurrence:   recurrence,
        cost_center:  cost_center,
        confidence:   confidence,
        source:       source,
        reasons:      reasons
      )
    end
  end
end
