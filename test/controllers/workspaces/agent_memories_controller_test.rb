require "test_helper"

# LGPD: o cliente vê e apaga o que o agente memorizou — e só do próprio workspace.
class Workspaces::AgentMemoriesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(name: "Mem", email: "memc_#{SecureRandom.hex(4)}@t.test", password: "senha1234")
    @workspace = Workspace.create!(name: "WS Mem", kind: "mei", owner: @user)
    @memory = WorkspaceMemory.remember!(@workspace, key: "ramo", value: "entregas", relevance: 50)
    sign_in @user
  end

  test "GET index lista as memórias do workspace" do
    get workspace_agent_memories_path(@workspace)
    assert_response :success
    assert_match(/entregas/, response.body)
  end

  test "DELETE destroy remove a memória (LGPD) e audita" do
    assert_difference -> { WorkspaceMemory.count }, -1 do
      delete workspace_agent_memory_path(@workspace, @memory)
    end
    assert_redirected_to workspace_agent_memories_path(@workspace)
    assert AuditLog.where(workspace_id: @workspace.id)
                   .where("reason LIKE ?", "%LGPD%").exists?
  end

  test "não apaga memória de workspace alheio" do
    intruder = User.create!(name: "I", email: "intm_#{SecureRandom.hex(4)}@t.test", password: "senha1234")
    sign_in intruder

    assert_no_difference -> { WorkspaceMemory.count } do
      delete workspace_agent_memory_path(@workspace, @memory)
    end
    assert_redirected_to workspaces_path
  end
end
