# frozen_string_literal: true

module Aionis
  # Agente Financeiro conversacional (WhatsApp + portal). Um ÚNICO orquestrador
  # (Agent::Conversation) serve os dois canais; a LLM nunca acessa o banco —
  # apenas escolhe tools, que o backend executa sempre escopadas pelo workspace
  # da sessão (Agent::Tools::*).
  module Agent
    # O agente só opera com um provedor de IA real que suporte chat/tools.
    def self.enabled?
      provider = Aionis::Integrations.ai
      provider.respond_to?(:chat) && provider.configured?
    end
  end
end
