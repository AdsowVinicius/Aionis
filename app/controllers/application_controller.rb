class ApplicationController < ActionController::Base
  include Pundit::Authorization

  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :authenticate_user!

  rescue_from Pundit::NotAuthorizedError, with: :handle_unauthorized

  helper_method :current_workspace

  private

  def current_workspace
    @current_workspace ||= begin
      if params[:workspace_id]
        current_user.workspaces.find(params[:workspace_id])
      end
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to workspaces_path, alert: "Workspace não encontrado."
  end

  def handle_unauthorized
    redirect_to root_path, alert: "Você não tem permissão para realizar esta ação."
  end
end
