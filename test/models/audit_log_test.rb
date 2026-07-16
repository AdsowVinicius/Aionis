require "test_helper"

class AuditLogTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(name: "Auditor", email: "audit_#{SecureRandom.hex(4)}@t.test", password: "senha1234")
    @workspace = Workspace.create!(name: "WS Audit", kind: "empresa", owner: @user)
    Current.reset
  end

  teardown { Current.reset }

  test "record! cria log com ação e origem válidas" do
    log = AuditLog.record!(action: "document_processing", origin: "job", workspace: @workspace,
                           provider: "fiscal_xml", confidence: 92, metadata: { a: 1 })
    assert log.persisted?
    assert_equal "document_processing", log.action
    assert_equal "job", log.origin
    assert_equal 92, log.confidence
    assert_equal({ "a" => 1 }, log.metadata)
  end

  test "valida inclusão de action e origin" do
    assert_raises(ActiveRecord::RecordInvalid) do
      AuditLog.record!(action: "inexistente", origin: "job", workspace: @workspace)
    end
    assert_raises(ActiveRecord::RecordInvalid) do
      AuditLog.record!(action: "create", origin: "inexistente", workspace: @workspace)
    end
  end

  test "é imutável após criado" do
    log = AuditLog.record!(action: "create", origin: "system", workspace: @workspace)
    assert_raises(ActiveRecord::ReadOnlyRecord) do
      log.update!(reason: "tentativa")
    end
  end

  test "log é resiliente e não propaga erro" do
    assert_nothing_raised do
      result = AuditLog.log(action: "invalida", origin: "job", workspace: @workspace)
      assert_nil result
    end
  end

  test "default_origin é user quando há Current.user, senão system" do
    Current.user = @user
    assert_equal "user", AuditLog.default_origin
    Current.user = nil
    assert_equal "system", AuditLog.default_origin
  end

  test "serializa datas e decimais no metadata" do
    log = AuditLog.record!(action: "create", origin: "system", workspace: @workspace,
                           metadata: { data: Date.new(2026, 7, 15), valor: BigDecimal("10.5") })
    assert_equal "2026-07-15", log.metadata["data"]
    assert_equal "10.5", log.metadata["valor"]
  end

  test "annotate injeta contexto e restaura ao final" do
    assert_nil Current.audit_annotation
    AuditLog.annotate(action: "reclassify", reason: "x") do
      assert_equal "reclassify", Current.audit_annotation[:action]
    end
    assert_nil Current.audit_annotation
  end

  test "scopes de consulta filtram por workspace, ação e origem" do
    AuditLog.record!(action: "create", origin: "user", workspace: @workspace)
    AuditLog.record!(action: "destroy", origin: "user", workspace: @workspace)
    outro_ws = Workspace.create!(name: "Outro", kind: "empresa", owner: @user)
    AuditLog.record!(action: "create", origin: "system", workspace: outro_ws)

    assert_equal 2, AuditLog.in_workspace(@workspace).count
    assert_equal 1, AuditLog.in_workspace(@workspace).with_action("create").count
    assert_equal 2, AuditLog.in_workspace(@workspace).with_origin("user").count
  end
end
