require "test_helper"

class CounterpartyTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      name: "Teste",
      email: "counterparty_test@aionis.test",
      password: "senha1234"
    )
    @workspace = Workspace.create!(name: "WS Teste", kind: "mei", owner: @user)
    @workspace2 = Workspace.create!(name: "WS Outro", kind: "cpf", owner: @user)
  end

  # Regra central: CPF/CNPJ nunca obrigatório
  test "salva sem tax_id" do
    c = Counterparty.new(workspace: @workspace, name: "Loja do Bairro", kind: "supplier")
    assert c.valid?, c.errors.full_messages.inspect
    assert c.save
    assert_equal "not_informed", c.tax_id_status
  end

  test "salva com CPF válido" do
    c = Counterparty.new(workspace: @workspace, name: "Pessoa Física", kind: "client", tax_id: "529.982.247-25")
    assert c.valid?, c.errors.full_messages.inspect
    assert_equal "informed", c.tax_id_status
  end

  test "rejeita CPF inválido quando preenchido" do
    c = Counterparty.new(workspace: @workspace, name: "Inválido", kind: "supplier", tax_id: "111.111.111-11")
    assert_not c.valid?
    assert c.errors[:tax_id].any?
  end

  test "rejeita tax_id duplicado no mesmo workspace" do
    Counterparty.create!(workspace: @workspace, name: "Fornecedor A", kind: "supplier", tax_id: "529.982.247-25")
    dup = Counterparty.new(workspace: @workspace, name: "Fornecedor B", kind: "supplier", tax_id: "529.982.247-25")
    assert_raises(ActiveRecord::RecordNotUnique) { dup.save! }
  end

  test "permite mesmo tax_id em workspaces diferentes" do
    Counterparty.create!(workspace: @workspace,  name: "F1", kind: "supplier", tax_id: "529.982.247-25")
    c2 = Counterparty.new(workspace: @workspace2, name: "F2", kind: "supplier", tax_id: "529.982.247-25")
    assert c2.valid?, c2.errors.full_messages.inspect
    assert c2.save
  end

  test "requer name" do
    c = Counterparty.new(workspace: @workspace, kind: "supplier")
    assert_not c.valid?
    assert c.errors[:name].any?
  end
end
