# frozen_string_literal: true

require "stringio"

module Aionis
  module Whatsapp
    # Orquestra o processamento de uma mensagem recebida do WhatsApp.
    #
    # Fluxo (chamado pelo InboundJob, fora da requisição web):
    #   parse_inbound (via Integrations.whatsapp) -> acha WorkspaceChannel ->
    #   registra IncomingMessage (dedup) -> se mídia: cria Document, extrai
    #   (OCR/Rule Engine) e faz a confirmação automática -> responde ao usuário.
    #
    # NÃO conhece Evolution: tudo passa por Aionis::Integrations.whatsapp.
    # Confirmação automática respeita as faixas de confiança do CLAUDE.md.
    class InboundProcessor
      SUPPORTED = Document::ALLOWED_CONTENT_TYPES
      AUTO_CONFIRM_MIN = 86
      REVIEW_MIN       = 61

      def self.call(instance:, payload:) = new(instance:, payload:).call

      def initialize(instance:, payload:)
        @instance = instance
        @payload  = payload
      end

      def call
        result = whatsapp.parse_inbound(@payload)
        return unless result.success?

        @data = result.data
        return if ignorable?

        @channel = WorkspaceChannel.find_by(instance: channel_instance)
        return log("canal não encontrado: #{channel_instance}") unless @channel
        @channel.touch_event!

        @incoming = build_incoming
        return if @incoming.nil? # duplicada — já processada

        audit("Mensagem recebida", incoming: true)
        @data["type"].in?(%w[document image]) ? process_media : process_text
        @incoming.processed!
        @incoming
      rescue => e
        Rails.logger.error("[Whatsapp::InboundProcessor] #{e.class}: #{e.message}")
        @incoming&.failed!
        nil
      end

      private

      def ignorable?
        @data["type"] == "ignored" || @data["from_me"] || @data["wa_message_id"].blank?
      end

      def channel_instance
        @instance.presence || @data["instance"]
      end

      def build_incoming
        return nil if @channel.incoming_messages.exists?(wa_message_id: @data["wa_message_id"])

        @channel.incoming_messages.create!(
          workspace:     @channel.workspace,
          wa_message_id: @data["wa_message_id"],
          from_number:   @data["from"],
          push_name:     @data["push_name"],
          kind:          @data["type"].in?(IncomingMessage::KINDS) ? @data["type"] : "other",
          text:          @data["text"],
          payload:       @payload,
          received_at:   parse_time(@data["received_at"]),
          status:        "received"
        )
      rescue ActiveRecord::RecordNotUnique
        nil
      end

      # --- Mídia (documento/imagem) ---

      def process_media
        dl = whatsapp.download_media(@data["media"], instance: @channel.instance)
        return reply(:cant_read) unless dl.success?

        content_type = dl.data["mimetype"]
        return reply(:unsupported) unless content_type.in?(SUPPORTED)

        document = build_document(dl.data, content_type)
        @incoming.update!(document: document)

        Aionis::DocumentExtractionService.call(document)
        auto_confirm(document)
      end

      def build_document(media, content_type)
        doc = @channel.workspace.documents.new(source: "whatsapp", status: "pending")
        doc.file.attach(
          io:           StringIO.new(media["bytes"]),
          filename:     media["filename"].presence || "whatsapp_#{@data['wa_message_id']}",
          content_type: content_type
        )
        doc.save!
        doc
      end

      # Confirmação automática conforme a confiança da extração.
      def auto_confirm(document)
        extraction = document.latest_extraction
        suggestion = extraction&.suggested_transaction_data || {}
        confidence = extraction&.confidence_score.to_i

        if suggestion["amount_cents"].blank?
          return reply(:low_confidence)
        elsif confidence >= AUTO_CONFIRM_MIN
          tx = create_transaction(document, extraction, suggestion, status: "confirmed")
          audit("Lançamento confirmado automaticamente", transaction: tx)
          reply(:confirmed, tx)
        elsif confidence >= REVIEW_MIN
          tx = create_transaction(document, extraction, suggestion, status: "pending")
          audit("Lançamento pendente de revisão", transaction: tx)
          reply(:review, tx)
        else
          reply(:low_confidence)
        end
      end

      def create_transaction(document, extraction, suggestion, status:)
        tx = @channel.workspace.financial_transactions.new(
          origin:        "document",
          document:      document,
          kind:          suggestion["kind"].presence || "expense",
          description:   suggestion["description"].presence || "Comprovante via WhatsApp",
          amount_cents:  suggestion["amount_cents"],
          transacted_on: parse_date(suggestion["transacted_on"]) || Date.current,
          status:        status,
          counterparty_name_snapshot:   suggestion["counterparty_name_snapshot"],
          counterparty_tax_id_snapshot: suggestion["counterparty_tax_id_snapshot"],
          counterparty_tax_id_status:   suggestion["counterparty_tax_id_status"]
        )
        classification = Aionis::ClassificationEngine.for_transaction(
          tx, extra_text: extraction&.raw_text
        ).call
        tx.apply_classification(classification, only_blank: true) if classification.present?
        tx.save!
        tx
      end

      # --- Texto ---

      def process_text
        reply(:help)
      end

      # --- Resposta (sempre via provider, com retry) ---

      def reply(kind, tx = nil)
        outgoing = @channel.outgoing_messages.create!(
          workspace:        @channel.workspace,
          incoming_message: @incoming,
          to_number:        @data["from"],
          body:             message_body(kind, tx),
          status:           "pending"
        )
        Aionis::Whatsapp::SendMessageJob.perform_later(outgoing.id)
        outgoing
      end

      def message_body(kind, tx)
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
        else # :help
          "Olá! Envie a foto ou o PDF do seu comprovante que eu registro pra você. 📎"
        end
      end

      # --- Helpers ---

      def audit(reason, incoming: false, transaction: nil)
        AuditLog.log(
          action:                "integration",
          origin:                "integration",
          workspace:             @channel.workspace,
          provider:              @channel.provider,
          document:              @incoming&.document,
          financial_transaction: transaction,
          reason:                reason,
          metadata: {
            channel_instance:   @channel.instance,
            incoming_message_id: @incoming&.id,
            from:               @data["from"],
            type:               @data["type"]
          }
        )
      end

      def whatsapp = Aionis::Integrations.whatsapp

      def brl(cents)
        format("R$ %.2f", cents.to_i / 100.0).sub(".", ",")
      end

      def parse_time(str)  = (Time.zone.parse(str.to_s) rescue nil) || Time.current
      def parse_date(str)  = (Date.parse(str.to_s) rescue nil)
      def log(message)     = Rails.logger.info("[Whatsapp::InboundProcessor] #{message}")
    end
  end
end
