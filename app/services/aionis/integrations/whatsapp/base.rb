# frozen_string_literal: true

module Aionis
  module Integrations
    module Whatsapp
      # Contrato de um provedor de WhatsApp (Evolution API, Meta Cloud, Twilio…).
      # Implementações concretas sobrescrevem estes métodos e retornam sempre um
      # Aionis::Integrations::Result. O restante do app NUNCA conhece o provedor
      # concreto — depende apenas deste contrato.
      #
      # `credentials:` transporta as credenciais por chamada (multi-tenant): o
      # provider extrai o que precisa (ex.: access_token/phone_number_id do Meta,
      # instance/api_key do Evolution) sem conhecer nenhum model do app.
      class Base < BaseProvider
        def send_text(to:, body:, instance: nil, credentials: nil)
          not_implemented!(:send_text)
        end

        def send_template(to:, name:, locale: "pt_BR", variables: [], instance: nil, credentials: nil)
          not_implemented!(:send_template)
        end

        def send_document(to:, media:, caption: nil, instance: nil, credentials: nil)
          not_implemented!(:send_document)
        end

        def send_image(to:, media:, caption: nil, instance: nil, credentials: nil)
          not_implemented!(:send_image)
        end

        def send_audio(to:, media:, instance: nil, credentials: nil)
          not_implemented!(:send_audio)
        end

        # Marca uma mensagem recebida como lida.
        def mark_as_read(message_id:, instance: nil, credentials: nil)
          not_implemented!(:mark_as_read)
        end

        # Normaliza o payload de webhook. Retorna data com "type":
        #   "message" -> { wa_message_id:, from:, push_name:, type: text/document/
        #                  image/audio, text:, media: { id/key, mimetype, filename },
        #                  phone_number_id:, instance:, received_at: }
        #   "status"  -> { wa_message_id:, status: sent/delivered/read/failed }
        #   "ignored" -> evento irrelevante
        def parse_inbound(payload)
          not_implemented!(:parse_inbound)
        end

        # Baixa o binário de uma mídia recebida.
        # @return [Result] data: { bytes:, mimetype:, filename:, url: }
        def download_media(media, instance: nil, credentials: nil)
          not_implemented!(:download_media)
        end

        # Handshake de verificação do webhook (GET hub.challenge do Meta, ou token).
        # @return [Result] data: { challenge: }
        def verify_webhook(token: nil, mode: nil, challenge: nil)
          not_implemented!(:verify_webhook)
        end

        # Valida a assinatura HMAC do corpo do webhook (X-Hub-Signature-256).
        def verify_signature(raw_body:, signature:)
          not_implemented!(:verify_signature)
        end
      end
    end
  end
end
