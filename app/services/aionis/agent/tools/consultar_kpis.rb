# frozen_string_literal: true

module Aionis
  module Agent
    module Tools
      # KPIs do período — reutiliza Aionis::Analytics::Kpis (o mesmo motor que o
      # DashboardPresenter compõe). Read-only.
      class ConsultarKpis < Base
        self.tool_name        = "consultar_kpis"
        self.tool_description = "Consulta os indicadores (KPIs) do mês: saldo, receitas, despesas, taxa de " \
                                "poupança, contas vencidas e a vencer. Use para 'como estão minhas finanças?'."
        self.input_schema = {
          type: "object",
          properties: {
            periodo: { type: "string", description: "Período em linguagem natural (usa o mês da data-base). " \
                                                    "Vazio = mês atual." }
          },
          required: []
        }

        def call(args)
          range = parse_period(args["periodo"])
          return period_error(args["periodo"]) unless range

          kpis = Aionis::Analytics::Kpis.new(workspace, on: range.begin).call
          audit("Agente consultou KPIs", periodo: args["periodo"])
          {
            "mes"                  => range.begin.strftime("%m/%Y"),
            "receitas_mes"         => brl(kpis.income_cents),
            "despesas_mes"         => brl(kpis.expense_cents),
            "saldo_mes"            => brl(kpis.balance_cents),
            "taxa_poupanca_pct"    => kpis.savings_rate,
            "lancamentos_pendentes" => kpis.pending_transactions_count,
            "contas_pagar_vencidas" => kpis.overdue_payables_count,
            "contas_receber_vencidas" => kpis.overdue_receivables_count,
            "a_pagar_proximos_7_dias" => brl(kpis.upcoming_payables_cents),
            "a_receber_proximos_7_dias" => brl(kpis.upcoming_receivables_cents)
          }
        end
      end
    end
  end
end
