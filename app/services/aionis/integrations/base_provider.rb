# frozen_string_literal: true

module Aionis
  module Integrations
    # Comportamento comum a todos os provedores de integração.
    #
    # Cada provedor recebe seu bloco de `settings` (credenciais/endpoints vindos
    # da config/ENV) na construção. Provedores concretos futuros implementam os
    # métodos declarados nas classes Base de cada domínio; enquanto isso, os
    # NullProviders respondem de forma segura sem nenhuma chamada externa.
    class BaseProvider
      attr_reader :settings

      def initialize(settings = {})
        @settings = (settings || {}).symbolize_keys
      end

      # Chave curta do provedor derivada do nome da classe.
      #   NullProvider      -> "null"
      #   MetaCloudProvider -> "meta_cloud"
      def provider_key
        self.class.name.demodulize.underscore.delete_suffix("_provider")
      end

      # Provedores concretos sobrescrevem para true quando têm credenciais.
      # NullProvider mantém false: sinaliza "não há integração real ativa".
      def configured?
        false
      end

      private

      def unavailable(message = nil)
        Result.unavailable(provider: provider_key, message: message || default_unavailable_message)
      end

      def not_implemented!(method)
        raise NotImplementedError,
              "#{self.class}##{method} ainda não foi implementado por este provedor"
      end

      def default_unavailable_message
        "Provedor '#{provider_key}' não configurado — nenhuma chamada externa implementada nesta etapa"
      end
    end
  end
end
