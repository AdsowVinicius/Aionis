class DashboardController < ApplicationController
  def index
    @workspaces = current_user.workspaces.order(:name)

    if @workspaces.none?
      redirect_to new_workspace_path,
                  notice: "Crie seu primeiro workspace para começar a usar o Aionis."
    elsif @workspaces.count == 1
      redirect_to workspace_dashboard_path(@workspaces.first)
    end
    # Múltiplos workspaces: renderiza seletor (index.html.erb)
  end
end
