require "test_helper"

class Workspaces::AuditLogsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(name: "Ctrl Audit", email: "auditctrl_#{SecureRandom.hex(4)}@t.test", password: "senha1234")
    @workspace = Workspace.create!(name: "WS AuditCtrl", kind: "empresa", owner: @user)
    sign_in @user
  end

  test "index lista logs do workspace" do
    AuditLog.record!(action: "create", origin: "user", workspace: @workspace, summary: "Log visível")
    get workspace_audit_logs_path(@workspace)
    assert_response :success
    assert_match "Log visível", @response.body
  end

  test "index filtra por ação" do
    AuditLog.record!(action: "create",  origin: "user", workspace: @workspace, summary: "Um create")
    AuditLog.record!(action: "destroy", origin: "user", workspace: @workspace, summary: "Um destroy")

    get workspace_audit_logs_path(@workspace, action_type: "destroy")
    assert_response :success
    assert_match "Um destroy", @response.body
    assert_no_match "Um create", @response.body
  end

  test "não mostra logs de outro workspace" do
    outro = Workspace.create!(name: "Outro", kind: "empresa", owner: @user)
    AuditLog.record!(action: "create", origin: "user", workspace: outro, summary: "Segredo alheio")

    get workspace_audit_logs_path(@workspace)
    assert_response :success
    assert_no_match "Segredo alheio", @response.body
  end

  test "show exibe detalhe do log" do
    log = AuditLog.record!(action: "update", origin: "user", workspace: @workspace,
                           before: { "name" => "A" }, after: { "name" => "B" }, reason: "trocou")
    get workspace_audit_log_path(@workspace, log)
    assert_response :success
    assert_match "trocou", @response.body
  end

  test "show de log de outro workspace retorna 404" do
    outro = Workspace.create!(name: "Outro", kind: "empresa", owner: @user)
    log = AuditLog.record!(action: "create", origin: "user", workspace: outro)
    get workspace_audit_log_path(@workspace, log)
    assert_response :not_found
  end
end
