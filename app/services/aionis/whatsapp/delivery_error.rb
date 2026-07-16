# frozen_string_literal: true

module Aionis
  module Whatsapp
    # Erro de entrega de mensagem — dispara retry no SendMessageJob.
    class DeliveryError < StandardError; end
  end
end
