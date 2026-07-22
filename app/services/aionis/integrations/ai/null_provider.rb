# frozen_string_literal: true

module Aionis
  module Integrations
    module Ai
      # Provedor padrão sem IA real. O motor de classificação continua operando
      # 100% com regras + histórico; a IA entra só quando um provedor real for
      # configurado. Nenhuma chamada externa aqui.
      class NullProvider < Base
        def classify(context:)          = unavailable
        def review(context:)            = unavailable
        def complete(prompt:, **options) = unavailable
        def chat(messages:, system: nil, tools: [], model: nil, max_tokens: nil) = unavailable
      end
    end
  end
end
