# frozen_string_literal: true

module Aionis
  module Agent
    module Tools
      # Grava/atualiza um fato ESTÁVEL afirmado pelo usuário (source:
      # user_stated). LGPD: nunca memoriza CPF/CNPJ ou padrão sensível — a
      # memória serve a preferências e contexto, não a dados pessoais de
      # terceiros.
      class SalvarMemoria < Base
        # CPF (formatado ou 11 dígitos) e CNPJ (formatado ou 14 dígitos).
        SENSITIVE_PATTERN = /
          \d{3}\.\d{3}\.\d{3}-\d{2} | \d{2}\.\d{3}\.\d{3}\/\d{4}-\d{2} |
          (?<!\d)\d{11}(?!\d) | (?<!\d)\d{14}(?!\d)
        /x

        self.tool_name        = "salvar_memoria"
        self.tool_description = "Memoriza um fato estável que o usuário AFIRMOU sobre si ou o negócio " \
                                "(ex.: 'combustível é essencial pra mim', 'meu ramo é construção'). " \
                                "NÃO use para dados temporários nem para CPF/CNPJ."
        self.input_schema = {
          type: "object",
          properties: {
            chave: { type: "string", description: "Identificador curto do fato, ex.: 'ramo', 'preferencia'." },
            valor: { type: "string", description: "O fato, em uma frase curta." }
          },
          required: %w[chave valor]
        }

        def call(args)
          return { "erro" => "Chave e valor são obrigatórios." } if args["chave"].blank? || args["valor"].blank?
          if args["valor"].to_s.match?(SENSITIVE_PATTERN) || args["chave"].to_s.match?(SENSITIVE_PATTERN)
            return { "erro" => "Não memorizo CPF/CNPJ nem dados sensíveis. Guarde apenas preferências e contexto." }
          end

          memory = WorkspaceMemory.remember!(
            workspace, key: args["chave"], value: args["valor"], source: "user_stated", relevance: 50
          )
          audit("Agente memorizou fato", chave: memory.key)
          { "memorizado" => true, "chave" => memory.key, "valor" => memory.value }
        rescue ActiveRecord::RecordInvalid => e
          { "erro" => e.record.errors.full_messages.to_sentence }
        end
      end
    end
  end
end
