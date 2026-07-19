module Workspaces
  # Painel (somente leitura) do WhatsApp. O número é único/global do Aionis e é
  # configurado por ENV (não por workspace). Aqui a pessoa apenas vê o status e
  # registra o próprio número de WhatsApp (Workspace#whatsapp_number, salvo via
  # WorkspacesController#update) para ser reconhecida nas mensagens.
  class WhatsappChannelsController < Workspaces::BaseController
    def index
      @channels          = current_workspace.workspace_channels.order(created_at: :desc)
      @provider_key      = Aionis::Integrations.active_provider_key(:whatsapp)
      @provider_ready    = Aionis::Integrations.configured?(:whatsapp)
      @last_incoming_at  = current_workspace.incoming_messages.maximum(:received_at)
    end
  end
end
