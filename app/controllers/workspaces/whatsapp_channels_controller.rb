module Workspaces
  # Gestão dos canais de WhatsApp do workspace. Controller fino: toda a regra de
  # conexão/rotação de credenciais vive em Aionis::Whatsapp::ChannelConnector.
  class WhatsappChannelsController < Workspaces::BaseController
    before_action :set_channel, only: [:edit, :update, :destroy]

    def index
      @channels = current_workspace.workspace_channels.order(created_at: :desc)
    end

    def new
      @channel = current_workspace.workspace_channels.new(provider: "meta_cloud", status: "pending")
    end

    def create
      @channel = Aionis::Whatsapp::ChannelConnector.connect(current_workspace, **connector_attrs)
      redirect_to workspace_whatsapp_channels_path(current_workspace),
                  notice: "Canal WhatsApp conectado com sucesso."
    rescue ActiveRecord::RecordInvalid => e
      @channel = e.record
      render :new, status: :unprocessable_entity
    end

    def edit; end

    def update
      @channel = Aionis::Whatsapp::ChannelConnector.connect(current_workspace, **connector_attrs)
      redirect_to workspace_whatsapp_channels_path(current_workspace),
                  notice: "Canal atualizado."
    rescue ActiveRecord::RecordInvalid => e
      @channel = e.record
      render :edit, status: :unprocessable_entity
    end

    def destroy
      @channel.destroy
      redirect_to workspace_whatsapp_channels_path(current_workspace),
                  notice: "Canal removido."
    end

    private

    def set_channel
      @channel = current_workspace.workspace_channels.find(params[:id])
    end

    # Monta os atributos para o ChannelConnector. Access token em branco na edição
    # NÃO sobrescreve o token existente.
    def connector_attrs
      permitted = params.require(:workspace_channel).permit(
        :provider, :phone_number_id, :business_account_id, :display_phone_number,
        :access_token, :verify_token, :webhook_secret, :instance
      ).to_h.symbolize_keys

      provider = permitted.delete(:provider).presence || "meta_cloud"
      permitted.reject! { |_k, v| v.blank? }
      { provider: provider, **permitted }
    end
  end
end
