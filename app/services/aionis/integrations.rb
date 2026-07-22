# frozen_string_literal: true

module Aionis
  # Camada de Integração (Integration Layer).
  #
  # Ponto único de acesso a provedores externos plugáveis. O restante do app
  # NÃO conhece implementações concretas — depende apenas destes métodos e do
  # contrato (Base) de cada domínio. Trocar de provedor é mudar a config/ENV
  # (config/aionis/integrations.yml), sem alterar consumidores.
  #
  #   Aionis::Integrations.ocr.extract(io:, content_type:)
  #   Aionis::Integrations.ai.classify(context: {...})
  #   Aionis::Integrations.whatsapp.send_text(to:, body:)
  #   Aionis::Integrations.open_finance.fetch_accounts(consent_id:)
  #
  # Injeção de dependência em testes:
  #   Aionis::Integrations.override(:ocr, FakeOcr.new)
  #   Aionis::Integrations.with(ai: FakeAi.new) { ... }
  #   Aionis::Integrations.reset!
  module Integrations
    TYPES = %i[whatsapp open_finance ocr ai].freeze

    class << self
      # provider: escolhe o provedor por canal (meta_cloud/evolution). Sem arg,
      # usa o provedor padrão da config (compatível com chamadas existentes).
      def whatsapp(provider: nil) = registry.resolve(:whatsapp, key: provider)
      def open_finance = registry.resolve(:open_finance)
      def ocr          = registry.resolve(:ocr)
      def ai           = registry.resolve(:ai)

      def resolve(type)     = registry.resolve(type)
      def configured?(type) = registry.configured?(type)
      def active_provider_key(type) = registry.active_provider_key(type)

      # Modo dry-run do ENVIO de WhatsApp: quando true, o SendMessageJob resolve
      # o DryRunProvider (não chama a Meta). Controlado por WHATSAPP_DRY_RUN;
      # default seguro por ambiente: true em dev/test, false em produção. Só
      # afeta a saída — o recebimento por webhook continua no provider real.
      def whatsapp_dry_run?
        parsed = ActiveModel::Type::Boolean.new.cast(ENV["WHATSAPP_DRY_RUN"])
        parsed.nil? ? !Rails.env.production? : parsed
      end

      def registry
        @registry ||= Registry.from_config
      end

      attr_writer :registry

      # Substitui um provedor (precedência sobre a config). Útil para testes,
      # feature flags ou rollout gradual de um provedor real.
      def override(type, provider)
        registry.override(type, provider)
        self
      end

      # Aplica overrides apenas dentro do bloco e restaura ao final.
      def with(overrides)
        overrides.each { |type, provider| registry.override(type, provider) }
        yield
      ensure
        overrides.each_key { |type| registry.clear_override(type) }
      end

      # Limpa overrides e instâncias memoizadas (recarrega da config).
      def reset!
        registry.reset!
        self
      end
    end
  end
end
