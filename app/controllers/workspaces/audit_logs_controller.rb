module Workspaces
  # Histórico de auditoria do workspace (somente leitura).
  class AuditLogsController < Workspaces::BaseController
    before_action :set_audit_log, only: :show

    PER_PAGE = 50

    def index
      scope = AuditLog.in_workspace(current_workspace).recent
      scope = scope.with_action(params[:action_type]) if AuditLog::ACTIONS.include?(params[:action_type])
      scope = scope.with_origin(params[:origin])      if AuditLog::ORIGINS.include?(params[:origin])
      scope = scope.where(user_id: params[:user_id])  if params[:user_id].present?

      @page  = [params[:page].to_i, 1].max
      @total = scope.count
      @logs  = scope.includes(:user).limit(PER_PAGE).offset((@page - 1) * PER_PAGE)
      @has_next = @total > @page * PER_PAGE

      @members = User.where(id: current_workspace.workspace_users.select(:user_id)).order(:name)
    end

    def show; end

    private

    def set_audit_log
      @log = AuditLog.in_workspace(current_workspace).find(params[:id])
    end
  end
end
