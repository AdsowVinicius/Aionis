# frozen_string_literal: true

module Aionis
  module Agent
    module Tools
      # Registra um lançamento manual. Regra do projeto (CLAUDE.md §2/§7):
      # descrição + valor + tipo BASTAM — categoria/fornecedor/data opcionais,
      # nada de CPF/CNPJ obrigatório. Regra de confiança: sem confirmação
      # explícita do usuário o lançamento nasce "pending" (revisável), nunca
      # efetivado às cegas. Classificação via ClassificationEngine (regras +
      # histórico; auto-aplica só com confiança alta).
      class RegistrarLancamento < Base
        self.tool_name        = "registrar_lancamento"
        self.tool_description = "Registra um lançamento financeiro (receita ou despesa). Antes de chamar, " \
                                "confirme com o usuário se algo estiver ambíguo (valor, tipo). Passe " \
                                "confirmado=true SOMENTE se o usuário confirmou explicitamente o registro."
        self.input_schema = {
          type: "object",
          properties: {
            descricao:  { type: "string",  description: "Descrição do lançamento." },
            valor:      { type: "string",  description: "Valor em reais, ex.: '120,50' ou '120.50'." },
            tipo:       { type: "string",  enum: %w[receita despesa], description: "Tipo do lançamento." },
            categoria:  { type: "string",  description: "Nome da categoria. Opcional." },
            fornecedor: { type: "string",  description: "Nome do fornecedor/cliente. Opcional." },
            data:       { type: "string",  description: "Data (AAAA-MM-DD ou DD/MM/AAAA). Opcional = hoje." },
            confirmado: { type: "boolean", description: "true apenas se o usuário confirmou explicitamente." }
          },
          required: %w[descricao valor tipo]
        }

        KIND_MAP = { "receita" => "income", "despesa" => "expense" }.freeze

        def call(args)
          kind = KIND_MAP[args["tipo"].to_s]
          return { "erro" => "Tipo inválido: use 'receita' ou 'despesa'." } unless kind
          return { "erro" => "Descrição é obrigatória." } if args["descricao"].blank?

          tx = workspace.financial_transactions.new(
            description:   args["descricao"].to_s.strip,
            kind:          kind,
            origin:        "manual",
            status:        args["confirmado"] == true ? "confirmed" : "pending",
            transacted_on: parse_date(args["data"])
          )
          tx.amount_brl = args["valor"].to_s
          return { "erro" => "Não entendi o valor \"#{args['valor']}\". Informe em reais, ex.: 120,50." } if tx.amount_cents.to_i <= 0

          assign_category(tx, args["categoria"])
          assign_counterparty(tx, args["fornecedor"])
          suggestion = classify(tx)

          return { "erro" => tx.errors.full_messages.to_sentence } unless tx.save

          audit("Agente registrou lançamento", financial_transaction_id: tx.id,
                                               confirmado: args["confirmado"] == true)
          result(tx, suggestion)
        end

        private

        def parse_date(text)
          return Date.current if text.blank?

          Date.parse(text.to_s)
        rescue ArgumentError
          Date.current
        end

        # Categoria por nome (workspace + globais). Nome desconhecido é ignorado
        # (fica para o motor de classificação) — nunca cria categoria nova.
        def assign_category(tx, name)
          return if name.blank?

          tx.category = Category.for_workspace(workspace).where("name ILIKE ?", "%#{name}%").first
        end

        # Fornecedor: vincula se já existir; senão guarda snapshot do nome
        # (sem criar Counterparty às cegas — CPF/CNPJ segue opcional).
        def assign_counterparty(tx, name)
          return if name.blank?

          existing = workspace.counterparties.where("name ILIKE ?", "%#{name}%").first
          existing ? tx.counterparty = existing : tx.counterparty_name_snapshot = name.to_s.strip
        end

        def classify(tx)
          return nil if tx.category_id.present?

          suggestion = Aionis::ClassificationEngine.for_transaction(tx).call
          tx.apply_classification(suggestion) if suggestion&.auto_applicable?
          suggestion
        rescue => e
          Rails.logger.error("[Agent::RegistrarLancamento] classificação falhou: #{e.message}")
          nil
        end

        def result(tx, suggestion)
          out = {
            "registrado" => true,
            "id"         => tx.id,
            "descricao"  => tx.description,
            "valor"      => brl(tx.amount_cents),
            "tipo"       => tx.income? ? "receita" : "despesa",
            "data"       => tx.transacted_on.strftime("%d/%m/%Y"),
            "categoria"  => tx.category&.name,
            "status"     => tx.status
          }
          if tx.pending?
            out["observacao"] = "Lançamento criado como PENDENTE — o usuário pode revisar/confirmar no app."
          end
          if suggestion&.present? && !suggestion.auto_applicable? && tx.category_id.blank?
            out["categoria_sugerida"] = suggestion.category&.name
          end
          out
        end
      end
    end
  end
end
