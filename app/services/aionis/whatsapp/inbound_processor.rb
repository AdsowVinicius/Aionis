# frozen_string_literal: true

module Aionis
  module Whatsapp
    # Primeiro passo do pipeline assíncrono (chamado pelo InboundJob):
    #   parse_inbound -> acha WorkspaceChannel -> persiste IncomingMessage (dedup)
    #   -> ENFILEIRA o próximo passo (DownloadMediaJob p/ mídia; resposta p/ texto).
    #
    # NÃO baixa mídia nem processa OCR aqui (fica nos jobs seguintes). Não conhece
    # Meta/Evolution: tudo via Aionis::Integrations.whatsapp(provider:).
    class InboundProcessor
      def self.call(provider:, payload:, instance: nil) = new(provider:, payload:, instance:).call

      def initialize(provider:, payload:, instance: nil)
        @provider = provider
        @payload  = payload
        @instance = instance
      end

      def call
        result = whatsapp.parse_inbound(@payload)
        return unless result.success?

        @data = result.data
        return StatusUpdater.call(@data) if @data["event"] == "status"
        return if ignorable?

        @channel = find_channel
        return log("canal não encontrado (#{@provider})") unless @channel
        @channel.touch_event!

        @incoming = build_incoming
        return if @incoming.nil? # idempotência: já recebida

        audit("Mensagem recebida")
        route
        @incoming
      rescue => e
        Rails.logger.error("[Whatsapp::InboundProcessor] #{e.class}: #{e.message}")
        @incoming&.failed!
        nil
      end

      private

      def ignorable?
        @data["event"] == "ignored" || @data["from_me"] || @data["wa_message_id"].blank?
      end

      def find_channel
        if @data["phone_number_id"].present?
          WorkspaceChannel.find_by(phone_number_id: @data["phone_number_id"])
        else
          WorkspaceChannel.find_by(instance: (@instance.presence || @data["instance"]))
        end
      end

      def build_incoming
        return nil if @channel.incoming_messages.exists?(wa_message_id: @data["wa_message_id"])

        @channel.incoming_messages.create!(
          workspace:     @channel.workspace,
          wa_message_id: @data["wa_message_id"],
          from_number:   @data["from"],
          push_name:     @data["push_name"],
          kind:          message_kind,
          text:          @data["text"],
          mime_type:     @data.dig("media", "mimetype"),
          payload:       { "raw" => @payload, "media" => @data["media"] },
          received_at:   parse_time(@data["received_at"]),
          status:        "received"
        )
      rescue ActiveRecord::RecordNotUnique
        nil # corrida de webhooks duplicados
      end

      def message_kind
        @data["type"].to_s.in?(IncomingMessage::KINDS) ? @data["type"] : "other"
      end

      # Enfileira o próximo passo conforme o tipo de mensagem.
      def route
        case @incoming.kind
        when "document", "image"
          audit("Documento recebido — download enfileirado")
          Aionis::Whatsapp::DownloadMediaJob.perform_later(@incoming.id)
        when "audio"
          # Arquitetura preparada; processamento de áudio ainda não implementado.
          Aionis::Whatsapp::Responder.reply(incoming: @incoming, kind: :audio_unsupported)
          @incoming.processed!
        else
          Aionis::Whatsapp::Responder.reply(incoming: @incoming, kind: :help)
          @incoming.processed!
        end
      end

      def audit(reason)
        AuditLog.log(
          action: "integration", origin: "integration",
          workspace: @channel.workspace, provider: @channel.provider,
          reason: reason,
          metadata: { incoming_message_id: @incoming&.id, from: @data["from"], type: @data["type"] }
        )
      end

      def whatsapp = Aionis::Integrations.whatsapp(provider: @provider)

      def parse_time(str) = (Time.zone.parse(str.to_s) rescue nil) || Time.current
      def log(message)    = Rails.logger.info("[Whatsapp::InboundProcessor] #{message}")
    end
  end
end
