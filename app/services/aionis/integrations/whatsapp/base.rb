# frozen_string_literal: true

module Aionis
  module Integrations
    module Whatsapp
      # Contrato de um provedor de WhatsApp (Evolution API, Meta Cloud, etc.).
      # Implementações concretas sobrescrevem estes métodos e retornam sempre um
      # Aionis::Integrations::Result. O restante do app NUNCA conhece o provedor
      # concreto — depende apenas deste contrato.
      class Base < BaseProvider
        # Envia mensagem de texto livre para um número, opcionalmente por uma
        # instância específica (multi-canal).
        # @return [Result] data: { message_id: }
        def send_text(to:, body:, instance: nil)
          not_implemented!(:send_text)
        end

        # Envia mensagem baseada em template aprovado.
        # @return [Result] data: { message_id: }
        def send_template(to:, name:, locale: "pt_BR", variables: [], instance: nil)
          not_implemented!(:send_template)
        end

        # Normaliza o payload de webhook em uma mensagem interna.
        # @return [Result] data: {
        #   instance:, wa_message_id:, from:, from_me:, type:, text:,
        #   media: { mimetype:, filename:, base64:, key: } | nil,
        #   push_name:, received_at: }
        def parse_inbound(payload)
          not_implemented!(:parse_inbound)
        end

        # Baixa o binário de uma mídia recebida.
        # @return [Result] data: { bytes:, mimetype:, filename: }
        def download_media(media, instance: nil)
          not_implemented!(:download_media)
        end

        # Valida a autenticidade de uma chamada de webhook (token) e/ou o
        # handshake de verificação (hub.challenge).
        # @return [Result] data: { challenge: }
        def verify_webhook(token:, mode: nil, challenge: nil)
          not_implemented!(:verify_webhook)
        end
      end
    end
  end
end
