# frozen_string_literal: true

module Aionis
  module Integrations
    module Whatsapp
      # Provedor de ENVIO para desenvolvimento/teste: NÃO chama a Meta. Apenas
      # loga o que seria enviado ([WHATSAPP_DRY_RUN]) e devolve um Result de
      # sucesso, para o pipeline (recebimento → OCR → classificação → lançamento
      # → resposta) rodar de ponta a ponta sem depender da API real.
      #
      # Existe porque a conta de teste da Meta pode estar bloqueada para envio
      # cross-country (erro 130497). O RECEBIMENTO continua no provider real
      # (MetaCloudProvider) — este provider só cobre a saída. A decisão de usá-lo
      # fica no SendMessageJob (via Aionis::Integrations.whatsapp_dry_run?), sem
      # quebrar o contrato dos providers reais nem a Integration Layer.
      #
      # Ativação: WHATSAPP_DRY_RUN (default true em dev/test, false em produção).
      class DryRunProvider < Base
        # Tem "credencial" no sentido de estar pronto para operar (não faz rede).
        def configured? = true

        def send_text(to:, body:, instance: nil, credentials: nil)
          log(:text, to, body)
        end

        def send_template(to:, name:, locale: "pt_BR", variables: [], instance: nil, credentials: nil)
          log(:template, to, "#{name} #{variables.join(', ')}".strip)
        end

        def send_document(to:, media:, caption: nil, instance: nil, credentials: nil)
          log(:document, to, caption || media)
        end

        def send_image(to:, media:, caption: nil, instance: nil, credentials: nil)
          log(:image, to, caption || media)
        end

        def send_audio(to:, media:, instance: nil, credentials: nil)
          log(:audio, to, media)
        end

        # Marcar como lida também é inócuo em dry-run.
        def mark_as_read(message_id:, instance: nil, credentials: nil)
          Result.ok(provider: provider_key, data: {})
        end

        # RECEBIMENTO nunca passa por aqui (o webhook/InboundProcessor pedem o
        # provider real explicitamente). Os métodos de entrada ficam com o
        # comportamento de Base (not_implemented!) de propósito: este provider é
        # exclusivo de envio.

        private

        def log(type, to, body)
          Rails.logger.info(
            "[WHATSAPP_DRY_RUN] envio suprimido — to=#{to} type=#{type} body=#{body.to_s.truncate(200)}"
          )
          Result.ok(provider: provider_key, data: { "message_id" => message_id, "dry_run" => true })
        end

        # Id sintético (não vem da Meta) para manter o registro consistente.
        def message_id = "dryrun-#{SecureRandom.uuid}"
      end
    end
  end
end
