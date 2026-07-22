# frozen_string_literal: true

module Aionis
  module Agent
    module Tools
      # Base das tools do Agente Financeiro. REGRA INEGOCIÁVEL: o workspace é
      # injetado pelo backend na construção — NUNCA vem da LLM. Toda consulta
      # parte de @workspace.financial_transactions/etc (escopo garantido).
      # Tools devolvem Hashes serializáveis (viram tool_result JSON); nunca
      # levantam exceção para a LLM — erros viram { "erro" => ... } amigável.
      class Base
        class_attribute :tool_name, :tool_description, :input_schema, instance_writer: false

        # Definição no formato da Messages API (tools:).
        def self.definition
          { name: tool_name, description: tool_description, input_schema: input_schema }
        end

        def initialize(workspace, user: nil, channel: nil)
          @workspace = workspace
          @user      = user
          @channel   = channel
        end

        def call(args)
          raise NotImplementedError
        end

        private

        attr_reader :workspace

        # Mesmo conceito de Analytics::Base — lançamentos que valem para o caixa.
        def realized
          workspace.financial_transactions
                   .where.not(status: "cancelled")
                   .where(settlement_status: [nil, "settled"])
        end

        DATE_SQL = Aionis::Analytics::Base::DATE_SQL

        def in_period(relation, range)
          relation.where("#{DATE_SQL} BETWEEN ? AND ?", range.begin, range.end)
        end

        # Período em linguagem natural -> Range validado no backend.
        # nil => o chamador deve devolver `period_error`.
        def parse_period(text) = PeriodParser.call(text)

        def period_error(text)
          { "erro" => "Não entendi o período \"#{text}\". Use, por exemplo: " \
                      "\"esse mês\", \"mês passado\", \"últimos 30 dias\", \"janeiro\"." }
        end

        def period_label(range) = "#{brl_date(range.begin)} a #{brl_date(range.end)}"
        def brl_date(date)      = date.strftime("%d/%m/%Y")

        def brl(cents)
          format("R$ %.2f", cents.to_i / 100.0).gsub(".", ",").sub(/,(\d{3},)/, '.\1')
        end

        # Auditoria obrigatória de toda ação do agente (consulta/registro/memória).
        def audit(reason, metadata = {})
          AuditLog.log(
            action: "ai", origin: "ai", workspace: workspace,
            provider: "agent", reason: reason,
            metadata: metadata.merge(tool: tool_name, channel: @channel)
          )
        end
      end
    end
  end
end
