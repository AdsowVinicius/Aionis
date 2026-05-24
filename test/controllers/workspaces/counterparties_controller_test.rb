require "test_helper"

class Workspaces::CounterpartiesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  # CNPJ e CPF válidos para testes (passam check-digit)
  VALID_CNPJ = "11.444.777/0001-61"
  VALID_CPF  = "529.982.247-25"

  setup do
    @user = User.create!(
      name: "CP Test",
      email: "cp_ctrl_#{SecureRandom.hex(4)}@aionis.test",
      password: "senha1234"
    )
    @workspace = Workspace.create!(name: "WS CP", kind: "empresa", owner: @user)
    sign_in @user
  end

  # 1. Usuário acessa lista do seu workspace
  test "GET index retorna sucesso" do
    get workspace_counterparties_path(@workspace)
    assert_response :success
  end

  # 2. Usuário abre tela de novo fornecedor/cliente
  test "GET new retorna sucesso" do
    get new_workspace_counterparty_path(@workspace)
    assert_response :success
  end

  # 3. Cria fornecedor sem CPF/CNPJ
  test "POST create sem CPF/CNPJ salva normalmente" do
    assert_difference("Counterparty.count") do
      post workspace_counterparties_path(@workspace), params: {
        counterparty: { name: "Loja do Bairro", kind: "supplier" }
      }
    end
    cp = Counterparty.last
    assert cp.tax_id.blank?
    assert_equal "not_informed", cp.tax_id_status
    assert_nil cp.tax_id_source
    assert_redirected_to workspace_counterparty_path(@workspace, cp)
  end

  # 4. Cria fornecedor com CNPJ válido
  test "POST create com CNPJ válido salva e define source como user_input" do
    assert_difference("Counterparty.count") do
      post workspace_counterparties_path(@workspace), params: {
        counterparty: { name: "Empresa SA", kind: "supplier", tax_id: VALID_CNPJ }
      }
    end
    cp = Counterparty.last
    assert_equal VALID_CNPJ, cp.tax_id
    assert_equal "informed",    cp.tax_id_status
    assert_equal "user_input",  cp.tax_id_source
    assert_redirected_to workspace_counterparty_path(@workspace, cp)
  end

  # 5. CPF/CNPJ inválido mostra erro e não salva
  test "POST create com CPF/CNPJ inválido renderiza new com erro" do
    assert_no_difference("Counterparty.count") do
      post workspace_counterparties_path(@workspace), params: {
        counterparty: { name: "Inválido", kind: "supplier", tax_id: "00.000.000/0000-00" }
      }
    end
    assert_response :unprocessable_entity
  end

  # 6. Edita fornecedor
  test "PATCH update atualiza nome e tipo" do
    cp = @workspace.counterparties.create!(name: "Original", kind: "supplier")
    patch workspace_counterparty_path(@workspace, cp), params: {
      counterparty: { name: "Atualizado", kind: "client" }
    }
    assert_redirected_to workspace_counterparty_path(@workspace, cp)
    cp.reload
    assert_equal "Atualizado", cp.name
    assert_equal "client",     cp.kind
  end

  # 6b. Edita adicionando CPF válido
  test "PATCH update adiciona CPF válido e define source como user_input" do
    cp = @workspace.counterparties.create!(name: "Sem CPF", kind: "supplier")
    patch workspace_counterparty_path(@workspace, cp), params: {
      counterparty: { name: "Sem CPF", kind: "supplier", tax_id: VALID_CPF }
    }
    cp.reload
    assert_equal VALID_CPF,    cp.tax_id
    assert_equal "user_input", cp.tax_id_source
    assert_equal "informed",   cp.tax_id_status
  end

  # 7. Show renderiza com sucesso
  test "GET show renderiza com sucesso" do
    cp = @workspace.counterparties.create!(name: "Ver Fornecedor", kind: "client")
    get workspace_counterparty_path(@workspace, cp)
    assert_response :success
  end

  # 8. Exclui fornecedor sem excluir lançamentos nem documentos
  test "DELETE destroy remove fornecedor mas mantém lançamentos e documentos" do
    cp = @workspace.counterparties.create!(name: "Para Excluir", kind: "supplier")
    tx = @workspace.financial_transactions.create!(
      kind: "expense", description: "Compra teste", amount_cents: 5000,
      origin: "manual", status: "pending", counterparty: cp
    )
    doc = @workspace.documents.new(source: "web", status: "pending", counterparty: cp)
    doc.save!(validate: false)

    assert_difference("Counterparty.count", -1) do
      delete workspace_counterparty_path(@workspace, cp)
    end
    assert_redirected_to workspace_counterparties_path(@workspace)

    # Lançamento e documento continuam existindo
    assert FinancialTransaction.exists?(tx.id)
    assert Document.exists?(doc.id)

    # Vínculo foi anulado
    assert_nil tx.reload.counterparty_id
    assert_nil doc.reload.counterparty_id
  end

  # 9. Fornecedor pertence ao workspace correto
  test "fornecedor criado pertence ao workspace do usuário" do
    post workspace_counterparties_path(@workspace), params: {
      counterparty: { name: "Dono Correto", kind: "supplier" }
    }
    assert_equal @workspace.id, Counterparty.last.workspace_id
  end

  # 10. Não acessa fornecedor de outro workspace
  test "não acessa fornecedor de outro workspace" do
    other_user = User.create!(
      name: "Invasor",
      email: "inv_cp_#{SecureRandom.hex(4)}@aionis.test",
      password: "senha1234"
    )
    other_ws = Workspace.create!(name: "WS Invasor", kind: "cpf", owner: other_user)
    other_cp = other_ws.counterparties.create!(name: "Outro", kind: "supplier")

    get workspace_counterparty_path(@workspace, other_cp)
    assert_response :not_found
  end

  # 11. CPF/CNPJ continua opcional em criação e edição
  test "CPF/CNPJ ausente não bloqueia criação nem edição" do
    # Cria sem CPF/CNPJ
    assert_difference("Counterparty.count") do
      post workspace_counterparties_path(@workspace), params: {
        counterparty: { name: "Sem CNPJ", kind: "both" }
      }
    end
    cp = Counterparty.last
    assert cp.tax_id.blank?

    # Edita sem CPF/CNPJ
    patch workspace_counterparty_path(@workspace, cp), params: {
      counterparty: { name: "Sem CNPJ Editado", kind: "both" }
    }
    assert_redirected_to workspace_counterparty_path(@workspace, cp)
    cp.reload
    assert cp.tax_id.blank?
    assert_equal "not_informed", cp.tax_id_status
  end

  # Busca por nome filtra corretamente
  test "GET index com query filtra por nome" do
    @workspace.counterparties.create!(name: "Alpha Ltda",   kind: "supplier")
    @workspace.counterparties.create!(name: "Beta Comércio", kind: "client")

    get workspace_counterparties_path(@workspace), params: { q: "Alpha" }
    assert_response :success
    assert_match "Alpha Ltda", response.body
    assert_no_match "Beta Comércio", response.body
  end
end
