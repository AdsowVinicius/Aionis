# frozen_string_literal: true

module Aionis
  module Agent
    module Tools
      # Saldo (receitas − despesas) de um período. Read-only.
      class ConsultarSaldo < Base
        self.tool_name        = "consultar_saldo"
        self.tool_description = "Consulta o saldo financeiro (receitas menos despesas) de um período. " \
                                "Use para perguntas como 'qual meu saldo?', 'sobrou dinheiro esse mês?'."
        self.input_schema = {
          type: "object",
          properties: {
            periodo: { type: "string",
                       description: "Período em linguagem natural: 'esse mês', 'mês passado', " \
                                    "'últimos 30 dias', 'janeiro'. Vazio = mês atual." }
          },
          required: []
        }

        def call(args)
          range = parse_period(args["periodo"])
          return period_error(args["periodo"]) unless range

          scoped  = in_period(realized, range)
          income  = scoped.where(kind: "income").sum(:amount_cents).to_i
          expense = scoped.where(kind: "expense").sum(:amount_cents).to_i

          audit("Agente consultou saldo", periodo: args["periodo"])
          {
            "periodo"  => period_label(range),
            "receitas" => brl(income),
            "despesas" => brl(expense),
            "saldo"    => brl(income - expense),
            "negativo" => (income - expense).negative?
          }
        end
      end
    end
  end
end
