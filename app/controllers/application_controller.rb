class ApplicationController < ActionController::Base
  include Pundit::Authorization

  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?

  layout :choose_layout

  rescue_from Pundit::NotAuthorizedError, with: :handle_unauthorized

  helper_method :current_workspace

  private

  def choose_layout
    devise_controller? ? "application" : (user_signed_in? ? "authenticated" : "application")
  end

  def current_workspace
    return @current_workspace if defined?(@current_workspace)
    @current_workspace = if params[:workspace_id]
      current_user.workspaces.find_by(id: params[:workspace_id])
    end
  end

  def require_workspace!
    return if current_workspace
    redirect_to workspaces_path, alert: "Workspace não encontrado ou sem permissão de acesso."
  end

  def after_sign_in_path_for(_resource)
    authenticated_root_path
  end

  def after_sign_up_path_for(_resource)
    authenticated_root_path
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up,         keys: [:name])
    devise_parameter_sanitizer.permit(:account_update,  keys: [:name])
  end

  def handle_unauthorized
    redirect_to root_path, alert: "Você não tem permissão para realizar esta ação."
  end
end
