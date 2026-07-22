# frozen_string_literal: true

module Aionis
  module Agent
    module Tools
      # Contas a pagar/receber (scopes payables/receivables/overdue/upcoming
      # do FinancialTransaction). Read-only.
      class ConsultarContas < Base
        self.tool_name        = "consultar_contas"
        self.tool_description = "Consulta contas a pagar ou a receber (pendentes, vencidas ou todas). " \
                                "Use para 'o que tenho pra pagar?', 'tem conta vencida?'."
        self.input_schema = {
          type: "object",
          properties: {
            tipo:   { type: "string", enum: %w[pagar receber], description: "Tipo da conta." },
            status: { type: "string", enum: %w[pendentes vencidas todas],
                      description: "Filtro (padrão: pendentes)." }
          },
          required: ["tipo"]
        }

        def call(args)
          base =
            case args["tipo"]
            when "pagar"   then workspace.financial_transactions.payables
            when "receber" then workspace.financial_transactions.receivables
            else return { "erro" => "Tipo inválido. Use 'pagar' ou 'receber'." }
            end

          scope =
            case args["status"].presence || "pendentes"
            when "vencidas" then base.overdue
            when "todas"    then base
            else base
            end

          items = scope.includes(:category, :counterparty).order(:due_on).limit(20)
          audit("Agente consultou contas", tipo: args["tipo"], status: args["status"])
          {
            "tipo"       => "contas a #{args['tipo']}",
            "quantidade" => items.size,
            "total"      => brl(scope.sum(:amount_cents)),
            "vencidas"   => base.overdue.count,
            "contas"     => items.map { |tx| serialize(tx) }
          }
        end

        private

        def serialize(tx)
          {
            "descricao"   => tx.description,
            "valor"       => brl(tx.amount_cents),
            "vencimento"  => tx.due_on&.strftime("%d/%m/%Y"),
            "vencida"     => tx.overdue?,
            "fornecedor"  => tx.counterparty&.name || tx.counterparty_name_snapshot
          }
        end
      end
    end
  end
end
