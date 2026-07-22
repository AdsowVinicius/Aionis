# frozen_string_literal: true

module Aionis
  module Agent
    module Tools
      # Lista lançamentos com filtros validados por enum no backend. Read-only.
      class ConsultarTransacoes < Base
        MAX_LIMIT = 20

        self.tool_name        = "consultar_transacoes"
        self.tool_description = "Lista lançamentos financeiros (receitas/despesas) com filtros. " \
                                "Use para 'quais foram meus últimos lançamentos?', 'o que entrou esse mês?'."
        self.input_schema = {
          type: "object",
          properties: {
            periodo: { type: "string", description: "Período em linguagem natural. Vazio = mês atual." },
            tipo:    { type: "string", enum: %w[receita despesa], description: "Filtra por tipo. Opcional." },
            status:  { type: "string", enum: %w[pending classified confirmed cancelled],
                       description: "Filtra por status. Opcional." },
            limite:  { type: "integer", description: "Máximo de itens (padrão 10, teto 20)." }
          },
          required: []
        }

        KIND_MAP = { "receita" => "income", "despesa" => "expense" }.freeze

        def call(args)
          range = parse_period(args["periodo"])
          return period_error(args["periodo"]) unless range

          scope = in_period(workspace.financial_transactions.where.not(status: "cancelled"), range)
          scope = scope.where(kind: KIND_MAP[args["tipo"]]) if KIND_MAP.key?(args["tipo"].to_s)
          scope = scope.where(status: args["status"]) if FinancialTransaction.statuses.key?(args["status"].to_s)

          limit = args["limite"].to_i.clamp(1, MAX_LIMIT)
          limit = 10 if args["limite"].blank?
          items = scope.includes(:category).order(Arel.sql("#{DATE_SQL} DESC")).limit(limit)

          audit("Agente listou transações", periodo: args["periodo"], tipo: args["tipo"], status: args["status"])
          {
            "periodo"    => period_label(range),
            "quantidade" => items.size,
            "lancamentos" => items.map { |tx| serialize(tx) }
          }
        end

        private

        def serialize(tx)
          {
            "data"      => (tx.transacted_on || tx.created_at.to_date).strftime("%d/%m/%Y"),
            "descricao" => tx.description,
            "valor"     => brl(tx.amount_cents),
            "tipo"      => tx.income? ? "receita" : "despesa",
            "categoria" => tx.category&.name,
            "status"    => tx.status
          }
        end
      end
    end
  end
end
