# frozen_string_literal: true

module Aionis
  module Integrations
    module Whatsapp
      # Provedor padrão sem integração real. Não faz chamadas externas: apenas
      # responde de forma previsível para o app funcionar em dev/test.
      class NullProvider < Base
        def send_text(to:, body:, instance: nil) = unavailable
        def send_template(to:, name:, locale: "pt_BR", variables: [], instance: nil) = unavailable
        def parse_inbound(payload) = unavailable
        def download_media(media, instance: nil) = unavailable
        def verify_webhook(token:, mode: nil, challenge: nil) = unavailable
      end
    end
  end
end
