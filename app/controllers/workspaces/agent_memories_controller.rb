module Workspaces
  # LGPD: o cliente vê e apaga o que o Agente Financeiro memorizou sobre ele.
  class AgentMemoriesController < Workspaces::BaseController
    def index
      @memories = current_workspace.workspace_memories.by_relevance
    end

    def destroy
      memory = current_workspace.workspace_memories.find(params[:id])
      memory.destroy
      AuditLog.log(
        action: "destroy", origin: "user", workspace: current_workspace, user: current_user,
        reason: "Memória do agente removida pelo cliente (LGPD)",
        metadata: { key: memory.key }
      )
      redirect_to workspace_agent_memories_path(current_workspace), notice: "Memória removida."
    end
  end
end
