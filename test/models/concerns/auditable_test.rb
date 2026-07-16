require "test_helper"

class AuditableTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(name: "Ator", email: "auditable_#{SecureRandom.hex(4)}@t.test", password: "senha1234")
    @workspace = Workspace.create!(name: "WS Auditable", kind: "empresa", owner: @user)
    Current.reset
    Current.user = @user
    Current.workspace = @workspace
  end

  teardown { Current.reset }

  test "cria log de criação com after preenchido e usuário do Current" do
    cp = nil
    assert_difference -> { AuditLog.count }, 1 do
      cp = @workspace.counterparties.create!(name: "Fornecedor Log", kind: "supplier")
    end
    log = AuditLog.for_auditable(cp).last
    assert_equal "create", log.action
    assert_equal @user.id, log.user_id
    assert_equal @workspace.id, log.workspace_id
    assert_equal "Fornecedor Log", log.after_data["name"]
    assert_empty log.before_data
  end

  test "cria log de edição com diff before/after" do
    cp = @workspace.counterparties.create!(name: "Original", kind: "supplier")
    assert_difference -> { AuditLog.count }, 1 do
      cp.update!(name: "Alterado")
    end
    log = AuditLog.for_auditable(cp).with_action("update").last
    assert_equal "Original", log.before_data["name"]
    assert_equal "Alterado", log.after_data["name"]
  end

  test "não gera log de update sem mudança real" do
    cp = @workspace.counterparties.create!(name: "Sem mudança", kind: "supplier")
    assert_no_difference -> { AuditLog.count } do
      cp.save! # nada mudou
    end
  end

  test "cria log de exclusão com before preenchido" do
    cp = @workspace.counterparties.create!(name: "Vai sumir", kind: "supplier")
    assert_difference -> { AuditLog.where(action: "destroy").count }, 1 do
      cp.destroy
    end
    log = AuditLog.where(action: "destroy").last
    assert_equal "Vai sumir", log.before_data["name"]
    assert_empty log.after_data
  end

  test "operação sem Current.user é atribuída ao sistema" do
    Current.user = nil
    cp = @workspace.counterparties.create!(name: "Sistema", kind: "supplier")
    log = AuditLog.for_auditable(cp).last
    assert_nil log.user_id
    assert_equal "system", log.origin
  end

  test "annotate sobrescreve a ação do log automático" do
    cp = @workspace.counterparties.create!(name: "Anotado", kind: "supplier")
    AuditLog.annotate(action: "reclassify", reason: "motivo") do
      cp.update!(name: "Novo nome")
    end
    log = AuditLog.for_auditable(cp).where(action: "reclassify").last
    assert_not_nil log
    assert_equal "motivo", log.reason
  end
end
