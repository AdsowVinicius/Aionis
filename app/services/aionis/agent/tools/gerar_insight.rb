# frozen_string_literal: true

module Aionis
  module Agent
    module Tools
      # Insights de saúde financeira — reutiliza Analytics::InsightGenerator e
      # HealthScore existentes (nada recalculado aqui). Read-only.
      class GerarInsight < Base
        self.tool_name        = "gerar_insight"
        self.tool_description = "Gera insights de saúde financeira do período (score de saúde, alertas de " \
                                "gastos, fôlego de caixa). Use para 'me dá um diagnóstico', 'como posso melhorar?'."
        self.input_schema = {
          type: "object",
          properties: {
            periodo: { type: "string", description: "Período (usa o mês da data-base). Vazio = mês atual." }
          },
          required: []
        }

        def call(args)
          range = parse_period(args["periodo"])
          return period_error(args["periodo"]) unless range

          on       = range.begin
          insights = Aionis::Analytics::InsightGenerator.new(workspace, on: on).build
          health   = Aionis::Analytics::HealthScore.new(workspace, on: on).call

          audit("Agente gerou insights", periodo: args["periodo"])
          {
            "mes"          => on.strftime("%m/%Y"),
            "score_saude"  => health.score,
            "faixa"        => health.band,
            "insights"     => insights.map { |i| { "severidade" => i[:severity], "titulo" => i[:title], "mensagem" => i[:message] } },
            "sem_alertas"  => insights.empty?
          }
        end
      end
    end
  end
end
