# frozen_string_literal: true

module Aionis
  module Whatsapp
    # Processa em background uma chamada de webhook do WhatsApp. O controller
    # só valida o token e enfileira este job (resposta 200 imediata).
    class InboundJob < ApplicationJob
      queue_as :default

      def perform(instance, payload)
        Aionis::Whatsapp::InboundProcessor.call(instance: instance, payload: payload)
      end
    end
  end
end
