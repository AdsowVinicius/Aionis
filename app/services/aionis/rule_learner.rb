# frozen_string_literal: true

require "set"

module Aionis
  # Aprende regras de classificação a partir das correções do usuário.
  #
  # Sempre que um lançamento é salvo com categoria escolhida MANUALMENTE
  # (classification_source == "manual") e essa escolha DIVERGE do que o motor
  # sugeriria sozinho, criamos ou reforçamos uma CategoryRule no nível do
  # workspace. Assim a próxima classificação semelhante já sai automática.
  # (CLAUDE.md §8: "Sempre salvar correções do usuário para melhorar próximas
  # classificações.")
  #
  # Estratégia da condição da regra (ordem de preferência — sinal mais forte
  # primeiro):
  #   1. fornecedor vinculado  -> regra por counterparty_id
  #   2. CPF/CNPJ (sem vínculo) -> regra por tax_id (só dígitos)
  #   3. nada disso            -> palavras-chave derivadas da descrição
  #
  # Nunca levanta erro para o fluxo do usuário: o chamador deve tratar como
  # best-effort. CPF/CNPJ continua opcional em todo o caminho.
  #
  #   Aionis::RuleLearner.for(transaction).call  # => CategoryRule | nil
  class RuleLearner
    # Palavras genéricas demais para virarem regra por palavra-chave.
    STOPWORDS = %w[
      de da do das dos e o a os as um uma uns umas ao aos no na nos nas em
      com para por pra pro que se sem sob sobre ate entre mais menos meu minha
      compra pagamento pago conta valor referente ref recibo nota fiscal loja
      mercado servico servicos produto produtos item itens diversos varios
    ].to_set.freeze

    MIN_KEYWORD_LENGTH = 4
    MAX_KEYWORDS       = 3

    # Confiança base ao criar e teto ao reforçar, por tipo de condição.
    BASE_CONFIDENCE = { counterparty: 82, tax_id: 80, keywords: 70 }.freeze
    CAP_CONFIDENCE  = { counterparty: 92, tax_id: 90, keywords: 82 }.freeze

    def self.for(transaction)
      new(transaction)
    end

    def initialize(transaction)
      @transaction = transaction
    end

    # Retorna a CategoryRule criada/reforçada, ou nil quando não há nada a aprender.
    def call
      return unless learnable?

      strategy = build_strategy
      return unless strategy

      existing = find_existing(strategy)
      if existing
        # Já existe regra aprendida para esta assinatura: o usuário confirmou
        # (ou trocou) a categoria de novo — sempre vale reforçar/repontar.
        reinforce(existing, strategy)
      elsif genuine_correction?
        # Não há regra aprendida ainda: só cria se for uma correção real frente
        # ao sistema NÃO-aprendido (regras seed/manuais + histórico). Evita
        # duplicar o que seeds ou histórico já classificam corretamente.
        create_rule(strategy)
      end
    end

    private

    attr_reader :transaction

    # --- Elegibilidade ---

    def learnable?
      transaction.persisted? &&
        transaction.workspace_id.present? &&
        transaction.category_id.present? &&
        transaction.classification_source == "manual"
    end

    # Verdadeiro quando a categoria escolhida difere do que o motor proporia
    # SEM as regras aprendidas (recalculado excluindo o próprio lançamento). Se
    # seeds/histórico já acertavam, não há correção nova a memorizar.
    def genuine_correction?
      suggestion = ClassificationEngine.for_transaction(transaction, exclude_learned: true).call
      suggestion.category_id != transaction.category_id
    end

    # --- Escolha da estratégia ---

    def build_strategy
      if transaction.counterparty_id.present?
        { type: :counterparty, counterparty_id: transaction.counterparty_id }
      elsif tax_digits.present?
        { type: :tax_id, tax_id: tax_digits }
      elsif (kws = derived_keywords).present?
        { type: :keywords, keywords: kws }
      end
    end

    def tax_digits
      return @tax_digits if defined?(@tax_digits)

      raw = transaction.counterparty&.tax_id.presence ||
            transaction.counterparty_tax_id_snapshot.presence
      @tax_digits = raw.to_s.gsub(/\D/, "").presence
    end

    # Tokens significativos da descrição, normalizados (minúsculo, sem acento),
    # ordenados para virar assinatura estável. Descarta stopwords e números.
    def derived_keywords
      CategoryRule.normalize(transaction.description)
                  .split(/[^a-z0-9]+/)
                  .reject { |t| t.length < MIN_KEYWORD_LENGTH || STOPWORDS.include?(t) || t.match?(/\A\d+\z/) }
                  .uniq
                  .first(MAX_KEYWORDS)
                  .sort
    end

    # --- Localizar regra aprendida equivalente ---

    def find_existing(strategy)
      scope = CategoryRule.learned.where(workspace_id: transaction.workspace_id, kind: transaction.kind)

      case strategy[:type]
      when :counterparty
        scope.find_by(counterparty_id: strategy[:counterparty_id])
      when :tax_id
        scope.find_by(tax_id: strategy[:tax_id])
      when :keywords
        signature = strategy[:keywords].join(",")
        scope.where.not(keywords: [nil, ""]).detect { |r| r.keywords_signature == signature }
      end
    end

    # --- Criar / reforçar ---

    def create_rule(strategy)
      rule = CategoryRule.new(
        workspace_id: transaction.workspace_id,
        origin:       "learned",
        active:       true,
        name:         rule_name(strategy),
        kind:         transaction.kind,
        category_id:  transaction.category_id,
        confidence:   BASE_CONFIDENCE.fetch(strategy[:type]),
        priority:     1,
        **conditions_for(strategy)
      )
      copy_classification_attrs(rule)
      rule.save!
      rule
    end

    def reinforce(rule, strategy)
      if rule.category_id == transaction.category_id
        rule.confidence = [rule.confidence + 3, CAP_CONFIDENCE.fetch(strategy[:type])].min
        rule.priority  += 1
      else
        # Usuário mudou de ideia: aponta para a nova categoria e reinicia a
        # confiança (mantém a prioridade acumulada).
        rule.category_id = transaction.category_id
        rule.confidence  = BASE_CONFIDENCE.fetch(strategy[:type])
        rule.name        = rule_name(strategy)
      end
      rule.times_reinforced += 1
      rule.active = true
      copy_classification_attrs(rule)
      rule.save!
      rule
    end

    # Colunas de condição de casamento, conforme a estratégia.
    def conditions_for(strategy)
      case strategy[:type]
      when :counterparty then { counterparty_id: strategy[:counterparty_id] }
      when :tax_id       then { tax_id: strategy[:tax_id] }
      when :keywords     then { keywords: strategy[:keywords].join(", ") }
      end
    end

    # Copia os atributos de classificação de forma livre do lançamento para a
    # regra. cost_type/essentiality ficam a cargo da categoria (como nas seeds).
    def copy_classification_attrs(rule)
      rule.scope       = transaction.scope       if transaction.scope.present?
      rule.recurrence  = transaction.recurrence  if transaction.recurrence.present?
      rule.cost_center = transaction.cost_center if transaction.cost_center.present?
    end

    def rule_name(strategy)
      alvo = transaction.category&.name || "categoria ##{transaction.category_id}"
      base =
        case strategy[:type]
        when :counterparty
          transaction.counterparty&.name || "fornecedor ##{strategy[:counterparty_id]}"
        when :tax_id
          "CPF/CNPJ #{strategy[:tax_id]}"
        when :keywords
          strategy[:keywords].join(", ")
        end
      "Aprendida: #{base} → #{alvo}"
    end
  end
end
