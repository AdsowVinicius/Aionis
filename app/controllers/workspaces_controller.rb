class WorkspacesController < ApplicationController
  before_action :set_workspace, only: [:show, :edit, :update, :destroy]

  def index
    @workspaces = current_user.workspaces.order(:name)
  end

  def show
    redirect_to workspace_dashboard_path(@workspace)
  end

  def new
    @workspace = Workspace.new
  end

  def create
    @workspace = Workspace.new(workspace_params)
    @workspace.owner = current_user
    if @workspace.save
      redirect_to workspace_dashboard_path(@workspace), notice: "Workspace criado com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @workspace.update(workspace_params)
      redirect_to workspace_dashboard_path(@workspace), notice: "Workspace atualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @workspace.destroy
    redirect_to workspaces_path, notice: "Workspace removido."
  end

  private

  def set_workspace
    @workspace = current_user.workspaces.find(params[:id])
  end

  def workspace_params
    params.require(:workspace).permit(:name, :kind, :tax_id)
  end
end
