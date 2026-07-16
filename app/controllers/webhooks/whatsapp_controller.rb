module Webhooks
  # Recebe webhooks do provedor de WhatsApp (Evolution). Isolado do restante do
  # app: herda ActionController::Base (sem Devise/Pundit/CSRF). Apenas valida o
  # token, enfileira o processamento e responde 200 imediatamente — o provedor
  # reenvia em caso de timeout, então o trabalho pesado fica no job.
  class WhatsappController < ActionController::Base
    skip_forgery_protection

    def create
      verification = Aionis::Integrations.whatsapp.verify_webhook(token: webhook_token)
      return head :unauthorized unless verification.success?

      Aionis::Whatsapp::InboundJob.perform_later(params[:instance], payload)
      head :ok
    rescue => e
      # Nunca devolve 5xx (evita tempestade de reenvios). O erro fica no log.
      Rails.logger.error("[Webhooks::Whatsapp] #{e.class}: #{e.message}")
      head :ok
    end

    private

    def webhook_token
      request.headers["apikey"].presence ||
        request.headers["Authorization"].to_s.delete_prefix("Bearer ").presence ||
        params[:token].presence
    end

    def payload
      request.body.rewind
      JSON.parse(request.body.read.presence || "{}")
    rescue JSON::ParserError
      {}
    end
  end
end
