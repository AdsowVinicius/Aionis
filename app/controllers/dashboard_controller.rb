class DashboardController < ApplicationController
  def index
    @workspaces = current_user.workspaces.includes(:subscription)
    if @workspaces.count == 1
      redirect_to workspace_dashboard_path(@workspaces.first)
    end
  end
end
