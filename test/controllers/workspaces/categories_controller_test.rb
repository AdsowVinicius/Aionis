require "test_helper"

class Workspaces::CategoriesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(
      name: "Cat Test",
      email: "cat_ctrl_#{SecureRandom.hex(4)}@aionis.test",
      password: "senha1234"
    )
    @workspace = Workspace.create!(name: "WS Cat", kind: "empresa", owner: @user)
    sign_in @user
  end

  # 1. Lista todas as categorias do workspace (globais + personalizadas)
  test "GET index retorna sucesso" do
    get workspace_categories_path(@workspace)
    assert_response :success
  end

  # 2. Filtro por nome funciona
  test "GET index filtra por nome" do
    @workspace.categories.create!(name: "Salário", kind: "income")
    @workspace.categories.create!(name: "Aluguel", kind: "expense")

    get workspace_categories_path(@workspace), params: { q: "Salário" }
    assert_response :success
    assert_match "Salário", response.body
    assert_no_match "Aluguel", response.body
  end

  # 3. Filtro por natureza funciona
  test "GET index filtra por kind" do
    @workspace.categories.create!(name: "ReceitaX", kind: "income")
    @workspace.categories.create!(name: "DespesaX", kind: "expense")

    get workspace_categories_path(@workspace), params: { kind: "income" }
    assert_response :success
    assert_match "ReceitaX", response.body
    assert_no_match "DespesaX", response.body
  end

  # 4. Abre tela de nova categoria
  test "GET new retorna sucesso" do
    get new_workspace_category_path(@workspace)
    assert_response :success
  end

  # 5. Cria categoria personalizada com sucesso
  test "POST create cria categoria do workspace" do
    assert_difference("Category.count") do
      post workspace_categories_path(@workspace), params: {
        category: { name: "Material de Escritório", kind: "expense" }
      }
    end
    cat = Category.last
    assert_equal @workspace.id, cat.workspace_id
    assert_equal "expense", cat.kind
    assert_redirected_to workspace_category_path(@workspace, cat)
  end

  # 6. Criação com campos opcionais
  test "POST create aceita cost_type e essentiality opcionais" do
    assert_difference("Category.count") do
      post workspace_categories_path(@workspace), params: {
        category: { name: "Combustível", kind: "expense",
                    cost_type: "variable", essentiality: "essential" }
      }
    end
    cat = Category.last
    assert_equal "variable",  cat.cost_type
    assert_equal "essential", cat.essentiality
  end

  # 7. Criação sem nome ou kind falha e renderiza new
  test "POST create sem nome renderiza new com erro" do
    assert_no_difference("Category.count") do
      post workspace_categories_path(@workspace), params: {
        category: { name: "", kind: "expense" }
      }
    end
    assert_response :unprocessable_entity
  end

  # 8. Show de categoria personalizada
  test "GET show categoria do workspace renderiza com sucesso" do
    cat = @workspace.categories.create!(name: "Minha Cat", kind: "income")
    get workspace_category_path(@workspace, cat)
    assert_response :success
  end

  # 9. Show de categoria global (sistema) renderiza com sucesso
  test "GET show categoria global renderiza com sucesso" do
    global_cat = Category.create!(name: "Global Test #{SecureRandom.hex(4)}", kind: "expense")
    get workspace_category_path(@workspace, global_cat)
    assert_response :success
  end

  # 10. Show de categoria de outro workspace retorna 404
  test "GET show categoria de outro workspace retorna 404" do
    other_user = User.create!(
      name: "Invasor",
      email: "inv_cat_#{SecureRandom.hex(4)}@aionis.test",
      password: "senha1234"
    )
    other_ws = Workspace.create!(name: "WS Invasor", kind: "cpf", owner: other_user)
    other_cat = other_ws.categories.create!(name: "Alheia", kind: "income")

    get workspace_category_path(@workspace, other_cat)
    assert_response :not_found
  end

  # 11. Edit de categoria personalizada funciona
  test "GET edit categoria do workspace retorna sucesso" do
    cat = @workspace.categories.create!(name: "Editável", kind: "income")
    get edit_workspace_category_path(@workspace, cat)
    assert_response :success
  end

  # 12. Edit de categoria global redireciona com alerta
  test "GET edit categoria global redireciona para show com alerta" do
    global_cat = Category.create!(name: "Global Edit #{SecureRandom.hex(4)}", kind: "expense")
    get edit_workspace_category_path(@workspace, global_cat)
    assert_redirected_to workspace_category_path(@workspace, global_cat)
    assert_match /não podem ser editadas/, flash[:alert]
  end

  # 13. Update de categoria personalizada funciona
  test "PATCH update atualiza categoria do workspace" do
    cat = @workspace.categories.create!(name: "Antes", kind: "income")
    patch workspace_category_path(@workspace, cat), params: {
      category: { name: "Depois", kind: "expense" }
    }
    assert_redirected_to workspace_category_path(@workspace, cat)
    cat.reload
    assert_equal "Depois",  cat.name
    assert_equal "expense", cat.kind
  end

  # 14. Update de categoria global redireciona com alerta
  test "PATCH update categoria global redireciona com alerta" do
    global_cat = Category.create!(name: "Global Update #{SecureRandom.hex(4)}", kind: "income")
    patch workspace_category_path(@workspace, global_cat), params: {
      category: { name: "Tentativa de Edição" }
    }
    assert_redirected_to workspace_category_path(@workspace, global_cat)
    assert_match /não podem ser editadas/, flash[:alert]
    assert_equal "Global Update", global_cat.reload.name.split(" ").first(2).join(" ")
  end

  # 15. Delete de categoria personalizada nullifica lançamentos
  test "DELETE destroy remove categoria e mantém lançamentos com category_id nil" do
    cat = @workspace.categories.create!(name: "Para Excluir", kind: "expense")
    tx = @workspace.financial_transactions.create!(
      kind: "expense", description: "Compra com categoria", amount_cents: 10000,
      origin: "manual", status: "pending", category: cat
    )

    assert_difference("Category.count", -1) do
      delete workspace_category_path(@workspace, cat)
    end
    assert_redirected_to workspace_categories_path(@workspace)

    assert FinancialTransaction.exists?(tx.id)
    assert_nil tx.reload.category_id
  end

  # 16. Delete de categoria com subcategorias também exclui subcategorias
  test "DELETE destroy categoria pai exclui subcategorias" do
    parent = @workspace.categories.create!(name: "Pai", kind: "expense")
    child  = @workspace.categories.create!(name: "Filho", kind: "expense", parent: parent)

    assert_difference("Category.count", -2) do
      delete workspace_category_path(@workspace, parent)
    end
    assert_not Category.exists?(child.id)
  end

  # 17. Delete de categoria global redireciona com alerta
  test "DELETE destroy categoria global redireciona com alerta" do
    global_cat = Category.create!(name: "Global Del #{SecureRandom.hex(4)}", kind: "income")
    assert_no_difference("Category.count") do
      delete workspace_category_path(@workspace, global_cat)
    end
    assert_redirected_to workspace_category_path(@workspace, global_cat)
    assert_match /não podem ser editadas/, flash[:alert]
  end

  # 18. Categoria criada pertence ao workspace correto
  test "categoria criada pertence ao workspace do usuário" do
    post workspace_categories_path(@workspace), params: {
      category: { name: "Do Workspace", kind: "income" }
    }
    assert_equal @workspace.id, Category.last.workspace_id
  end
end
