module Workspaces
  # Chat do Agente Financeiro no portal. Controller FINO: recebe a mensagem e
  # delega ao orquestrador (Aionis::Agent::Conversation) — nenhuma IA aqui.
  class ChatController < Workspaces::BaseController
    def show
      @messages      = current_workspace.agent_messages.for_channel("portal").chronological.last(50)
      @agent_enabled = Aionis::Agent.enabled?
    end

    def create
      message = params[:message].to_s.strip
      if message.blank?
        redirect_to workspace_chat_path(current_workspace) and return
      end

      @reply = Aionis::Agent::Conversation.call(
        workspace: current_workspace,
        message:   message,
        channel:   "portal",
        user:      current_user
      )
      @user_message = message

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to workspace_chat_path(current_workspace) }
      end
    end
  end
end
