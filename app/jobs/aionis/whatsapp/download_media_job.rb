# frozen_string_literal: true

require "stringio"

module Aionis
  module Whatsapp
    # Baixa a mídia do WhatsApp, anexa ao Document (ActiveStorage) e dispara o
    # ProcessDocumentJob. Fora da requisição web. Retries com backoff exponencial
    # para falhas transitórias (rate limit/5xx). Auditado em cada etapa.
    class DownloadMediaJob < ApplicationJob
      queue_as :default

      retry_on Aionis::Whatsapp::DeliveryError, attempts: 4, wait: :polynomially_longer do |job, error|
        incoming = IncomingMessage.find_by(id: job.arguments.first)
        if incoming
          Aionis::Whatsapp::Responder.reply(incoming: incoming, kind: :cant_read)
          incoming.failed!
        end
        Rails.logger.error("[DownloadMediaJob] esgotou retries: #{error.message}")
      end

      def perform(incoming_id)
        incoming = IncomingMessage.find_by(id: incoming_id)
        return unless incoming

        @channel = incoming.workspace_channel
        audit(incoming, "Download de mídia iniciado")

        result = provider.download_media(media_descriptor(incoming), credentials: @channel.credentials)

        unless result.success?
          raise DeliveryError, "download transitório: #{result.message}" if result.status == :pending

          audit(incoming, "Falha no download: #{result.message}")
          Aionis::Whatsapp::Responder.reply(incoming: incoming, kind: :cant_read)
          incoming.failed!
          return
        end

        content_type = result.data["mimetype"]
        unless content_type.in?(Document::ALLOWED_CONTENT_TYPES)
          Aionis::Whatsapp::Responder.reply(incoming: incoming, kind: :unsupported)
          incoming.processed!
          return
        end

        document = build_document(incoming, result.data, content_type)
        incoming.update!(document: document, mime_type: content_type,
                         media_url: result.data["url"], status: "processed")
        mark_read(incoming)
        audit(incoming, "Download concluído — documento anexado", document: document)

        ProcessDocumentJob.perform_later(document.id)
      end

      private

      def media_descriptor(incoming)
        (incoming.payload["media"] || {}).merge(
          "mimetype" => incoming.mime_type || incoming.payload.dig("media", "mimetype")
        )
      end

      def build_document(incoming, data, content_type)
        doc = @channel.workspace.documents.new(source: "whatsapp", status: "pending")
        doc.file.attach(
          io:           StringIO.new(data["bytes"].to_s),
          filename:     data["filename"].presence || "whatsapp_#{incoming.wa_message_id}",
          content_type: content_type
        )
        doc.save!
        doc
      end

      def mark_read(incoming)
        provider.mark_as_read(message_id: incoming.wa_message_id, credentials: @channel.credentials)
      rescue => e
        Rails.logger.warn("[DownloadMediaJob] mark_as_read falhou: #{e.message}")
      end

      def provider = Aionis::Integrations.whatsapp(provider: @channel.provider)

      def audit(incoming, reason, document: nil)
        AuditLog.log(
          action: "integration", origin: "integration",
          workspace: @channel.workspace, provider: @channel.provider, document: document,
          reason: reason, metadata: { incoming_message_id: incoming.id }
        )
      end
    end
  end
end
