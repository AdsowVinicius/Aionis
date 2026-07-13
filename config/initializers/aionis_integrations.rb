# frozen_string_literal: true

# Camada de Integração (Aionis::Integrations).
#
# O registro é lazy: a primeira chamada a Aionis::Integrations.<tipo> carrega a
# config (config/aionis/integrations.yml) e resolve o provedor ativo. Não há
# nenhuma chamada externa em boot — apenas leitura de config/ENV.
#
# Em produção, valida na inicialização que todos os provedores configurados
# podem ser instanciados (falha cedo em caso de classe/typo inválido), sem
# executar nenhuma integração de fato.
Rails.application.config.after_initialize do
  next unless Rails.env.production?

  Aionis::Integrations::TYPES.each do |type|
    Aionis::Integrations.resolve(type)
  rescue StandardError => e
    Rails.logger.error("[Integrations] Falha ao resolver provedor de #{type}: #{e.class} #{e.message}")
    raise
  end
end
