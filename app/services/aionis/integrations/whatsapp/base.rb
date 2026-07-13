# frozen_string_literal: true

module Aionis
  module Integrations
    module Whatsapp
      # Contrato de um provedor de WhatsApp (ex.: Meta WhatsApp Cloud API).
      # Implementações concretas devem sobrescrever todos os métodos e retornar
      # um Aionis::Integrations::Result. Nenhuma chamada externa nesta etapa.
      class Base < BaseProvider
        # Envia mensagem de texto livre.
        # @return [Result] data: { message_id: }
        def send_text(to:, body:)
          not_implemented!(:send_text)
        end

        # Envia mensagem baseada em template aprovado.
        # @return [Result] data: { message_id: }
        def send_template(to:, name:, locale: "pt_BR", variables: [])
          not_implemented!(:send_template)
        end

        # Normaliza o payload de webhook em uma mensagem interna.
        # @return [Result] data: { from:, text:, media:, wa_message_id:, received_at: }
        def parse_inbound(payload)
          not_implemented!(:parse_inbound)
        end

        # Verifica o handshake de webhook (hub.challenge).
        # @return [Result] data: { challenge: }
        def verify_webhook(mode:, token:, challenge:)
          not_implemented!(:verify_webhook)
        end
      end
    end
  end
end
