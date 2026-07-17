# frozen_string_literal: true

module Aionis
  module Whatsapp
    # Processa em background uma chamada de webhook do WhatsApp. O controller só
    # valida (assinatura/token) e enfileira este job (resposta 200 imediata).
    # `provider` = chave do provedor (meta_cloud/evolution).
    class InboundJob < ApplicationJob
      queue_as :default

      def perform(provider, payload, instance = nil)
        Aionis::Whatsapp::InboundProcessor.call(provider: provider, payload: payload, instance: instance)
      end
    end
  end
end
