module Webhooks
  # Webhook do WhatsApp. Isolado (ActionController::Base, sem Devise/Pundit/CSRF).
  # Extremamente fino: valida (assinatura/token), responde imediatamente e
  # enfileira todo o restante (download/OCR/classificação ficam nos jobs).
  # Nunca conhece Meta/Evolution — delega ao provider via Integration Layer.
  class WhatsappController < ActionController::Base
    skip_forgery_protection

    # GET — handshake de verificação da Meta (hub.challenge).
    def verify
      result = meta.verify_webhook(
        mode:      params["hub.mode"],
        token:     params["hub.verify_token"],
        challenge: params["hub.challenge"]
      )
      return head :forbidden unless result.success?

      render plain: result.data["challenge"].to_s
    end

    # POST — eventos da Meta (mensagens/status). Valida assinatura HMAC.
    def receive
      raw = request.raw_post
      result = meta.verify_signature(raw_body: raw, signature: request.headers["X-Hub-Signature-256"])
      return head :unauthorized unless result.success?

      Aionis::Whatsapp::InboundJob.perform_later("meta_cloud", parse(raw))
      head :ok
    rescue => e
      Rails.logger.error("[Webhooks::Whatsapp#receive] #{e.class}: #{e.message}")
      head :ok
    end

    # POST — Evolution (validação por token). Mantido p/ compatibilidade.
    def create
      result = Aionis::Integrations.whatsapp(provider: "evolution").verify_webhook(token: webhook_token)
      return head :unauthorized unless result.success?

      Aionis::Whatsapp::InboundJob.perform_later("evolution", payload, params[:instance])
      head :ok
    rescue => e
      Rails.logger.error("[Webhooks::Whatsapp#create] #{e.class}: #{e.message}")
      head :ok
    end

    private

    def meta = Aionis::Integrations.whatsapp(provider: "meta_cloud")

    def webhook_token
      request.headers["apikey"].presence ||
        request.headers["Authorization"].to_s.delete_prefix("Bearer ").presence ||
        params[:token].presence
    end

    def payload
      request.body.rewind
      parse(request.body.read)
    end

    def parse(raw)
      JSON.parse(raw.presence || "{}")
    rescue JSON::ParserError
      {}
    end
  end
end
