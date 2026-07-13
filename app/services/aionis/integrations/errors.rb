# frozen_string_literal: true

module Aionis
  module Integrations
    module Errors
      # Erro base da camada de integração
      class Error < StandardError; end

      # Tipo de integração desconhecido (fora de Aionis::Integrations::TYPES)
      class UnknownIntegrationType < Error; end

      # Provedor referenciado na config não está mapeado
      class UnknownProvider < Error; end

      # Classe do provedor configurada não pôde ser carregada
      class ProviderNotLoadable < Error; end
    end
  end
end
