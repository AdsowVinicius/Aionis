# frozen_string_literal: true

module Aionis
  module Integrations
    module Whatsapp
      # Provedor padrão sem integração real. Não faz chamadas externas: apenas
      # responde de forma previsível para o app funcionar em dev/test.
      class NullProvider < Base
        def send_text(to:, body:, instance: nil, credentials: nil) = unavailable
        def send_template(to:, name:, locale: "pt_BR", variables: [], instance: nil, credentials: nil) = unavailable
        def send_document(to:, media:, caption: nil, instance: nil, credentials: nil) = unavailable
        def send_image(to:, media:, caption: nil, instance: nil, credentials: nil) = unavailable
        def send_audio(to:, media:, instance: nil, credentials: nil) = unavailable
        def mark_as_read(message_id:, instance: nil, credentials: nil) = unavailable
        def parse_inbound(payload) = unavailable
        def download_media(media, instance: nil, credentials: nil) = unavailable
        def verify_webhook(token: nil, mode: nil, challenge: nil) = unavailable
        def verify_signature(raw_body:, signature:) = unavailable
      end
    end
  end
end
