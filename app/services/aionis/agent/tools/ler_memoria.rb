# frozen_string_literal: true

module Aionis
  module Agent
    module Tools
      # Lê fatos memorizados do workspace (read-only). LGPD: o mesmo conteúdo é
      # visível/apagável pelo cliente no portal.
      class LerMemoria < Base
        self.tool_name        = "ler_memoria"
        self.tool_description = "Lê os fatos memorizados sobre este cliente/workspace (ramo, preferências, " \
                                "fornecedores frequentes). Use antes de assumir algo sobre o cliente."
        self.input_schema = {
          type: "object",
          properties: {
            chave: { type: "string", description: "Filtra por uma chave específica. Opcional." }
          },
          required: []
        }

        def call(args)
          scope = workspace.workspace_memories.by_relevance
          scope = scope.where(key: args["chave"].to_s.strip.downcase) if args["chave"].present?

          facts = scope.limit(50).map do |m|
            { "chave" => m.key, "valor" => m.value, "origem" => m.source }
          end
          audit("Agente leu memória", chave: args["chave"])
          facts.empty? ? { "memorias" => [], "observacao" => "Nada memorizado ainda." } : { "memorias" => facts }
        end
      end
    end
  end
end
