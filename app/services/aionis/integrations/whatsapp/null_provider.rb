# frozen_string_literal: true

module Aionis
  module Integrations
    module Whatsapp
      # Provedor padrão sem integração real. Não faz chamadas externas: apenas
      # responde de forma previsível para o app funcionar em dev/test.
      class NullProvider < Base
        def send_text(to:, body:)          = unavailable
        def send_template(to:, name:, locale: "pt_BR", variables: []) = unavailable
        def parse_inbound(payload)         = unavailable
        def verify_webhook(mode:, token:, challenge:) = unavailable
      end
    end
  end
end
