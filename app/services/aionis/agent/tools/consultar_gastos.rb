# frozen_string_literal: true

module Aionis
  module Agent
    module Tools
      # Gastos de um período, com filtro opcional por categoria/fornecedor e
      # quebra pelas maiores categorias. Read-only.
      class ConsultarGastos < Base
        self.tool_name        = "consultar_gastos"
        self.tool_description = "Consulta despesas de um período, opcionalmente filtrando por categoria ou " \
                                "fornecedor. Use para 'quanto gastei com X?', 'meus maiores gastos'."
        self.input_schema = {
          type: "object",
          properties: {
            periodo:    { type: "string", description: "Período em linguagem natural. Vazio = mês atual." },
            categoria:  { type: "string", description: "Nome (ou parte) da categoria. Opcional." },
            fornecedor: { type: "string", description: "Nome (ou parte) do fornecedor. Opcional." }
          },
          required: []
        }

        def call(args)
          range = parse_period(args["periodo"])
          return period_error(args["periodo"]) unless range

          scope = in_period(realized.where(kind: "expense"), range)
          scope = filter_category(scope, args["categoria"])
          scope = filter_counterparty(scope, args["fornecedor"])

          total = scope.sum(:amount_cents).to_i
          audit("Agente consultou gastos", periodo: args["periodo"],
                                           categoria: args["categoria"], fornecedor: args["fornecedor"])
          {
            "periodo"           => period_label(range),
            "total"             => brl(total),
            "quantidade"        => scope.count,
            "maiores_categorias" => top_categories(scope)
          }
        end

        private

        def filter_category(scope, name)
          return scope if name.blank?

          ids = Category.for_workspace(workspace).where("name ILIKE ?", "%#{name}%").select(:id)
          scope.where(category_id: ids)
        end

        def filter_counterparty(scope, name)
          return scope if name.blank?

          ids = workspace.counterparties.where("name ILIKE ?", "%#{name}%").select(:id)
          scope.where(counterparty_id: ids)
              .or(scope.where("counterparty_name_snapshot ILIKE ?", "%#{name}%"))
        end

        def top_categories(scope)
          scope.joins(:category).group("categories.name")
               .sum(:amount_cents)
               .sort_by { |_name, cents| -cents }
               .first(5)
               .map { |name, cents| { "categoria" => name, "total" => brl(cents) } }
        end
      end
    end
  end
end
