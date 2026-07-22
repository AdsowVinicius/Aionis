# frozen_string_literal: true

module Aionis
  module Whatsapp
    # Cria a mensagem de resposta (OutgoingMessage) e enfileira o envio. Único
    # ponto de composição de respostas — reutilizado por InboundProcessor,
    # DownloadMediaJob e AutoConfirmJob (DRY). Auditado.
    class Responder
      def self.reply(incoming:, kind:, transaction: nil) = new(incoming).reply(kind, transaction)

      # Resposta com corpo livre (usada pelo Agente Financeiro) — mesmo caminho
      # de OutgoingMessage + SendMessageJob + auditoria das respostas fixas.
      def self.reply_custom(incoming:, body:) = new(incoming).deliver(body, kind: :agent)

      def initialize(incoming)
        @incoming = incoming
        @channel  = incoming.workspace_channel
      end

      def reply(kind, transaction = nil)
        deliver(body(kind, transaction), kind: kind, transaction: transaction)
      end

      def deliver(text, kind:, transaction: nil)
        outgoing = @channel.outgoing_messages.create!(
          workspace:        @channel.workspace,
          incoming_message: @incoming,
          to_number:        @incoming.from_number,
          message_type:     "text",
          body:             text,
          status:           "pending"
        )
        Aionis::Whatsapp::SendMessageJob.perform_later(outgoing.id)

        AuditLog.log(
          action: "integration", origin: "integration",
          workspace: @channel.workspace, provider: @channel.provider,
          financial_transaction: transaction,
          reason: "Resposta enfileirada (#{kind})",
          metadata: { outgoing_message_id: outgoing.id, kind: kind }
        )
        outgoing
      end

      private

      def body(kind, tx)
        case kind
        when :confirmed
          "✅ Lançamento registrado: #{tx.description} — #{brl(tx.amount_cents)}" \
            "#{" · #{tx.category.name}" if tx.category}. (confiança alta)"
        when :review
          "📄 Recebi seu comprovante e criei um lançamento de #{brl(tx.amount_cents)} " \
            "pendente de confirmação. Confira no app."
        when :low_confidence
          "😕 Não consegui ler o comprovante com segurança. Pode reenviar uma foto mais nítida?"
        when :unsupported
          "Recebi seu arquivo, mas só consigo ler foto (JPG/PNG) ou PDF de comprovantes."
        when :cant_read
          "Não consegui baixar seu arquivo. Pode reenviar, por favor?"
        when :audio_unsupported
          "Recebi seu áudio! Por enquanto só processo comprovantes em foto (JPG/PNG) ou PDF."
        else # :help
          "Olá! Envie a foto ou o PDF do seu comprovante que eu registro pra você. 📎"
        end
      end

      def brl(cents)
        format("R$ %.2f", cents.to_i / 100.0).sub(".", ",")
      end
    end
  end
end
