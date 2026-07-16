require "test_helper"

class Workspaces::CategoryRulesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(
      name: "Rules Test",
      email: "rules_#{SecureRandom.hex(4)}@aionis.test",
      password: "senha1234"
    )
    @workspace = Workspace.create!(name: "WS Rules", kind: "empresa", owner: @user)
    @category  = Category.create!(name: "Transporte #{SecureRandom.hex(2)}", kind: "expense",
                                  cost_type: "variable", essentiality: "operational_important")
    sign_in @user
  end

  test "index lista regras globais e do workspace" do
    global = CategoryRule.create!(name: "Global X", keywords: "gasolina", origin: "seed")
    minha  = CategoryRule.create!(name: "Minha regra", keywords: "uber", workspace: @workspace,
                                  origin: "manual", category: @category)

    get workspace_category_rules_path(@workspace)
    assert_response :success
    assert_match global.name, @response.body
    assert_match minha.name,  @response.body
  end

  test "cria regra manual com palavra-chave" do
    assert_difference -> { CategoryRule.where(workspace_id: @workspace.id, origin: "manual").count }, 1 do
      post workspace_category_rules_path(@workspace), params: {
        category_rule: {
          name: "Transporte por app", kind: "expense", keywords: "uber, 99, taxi",
          category_id: @category.id, confidence: 80, priority: 5, active: "1"
        }
      }
    end
    assert_redirected_to workspace_category_rules_path(@workspace)
    regra = CategoryRule.order(:created_at).last
    assert_equal "manual", regra.origin
    assert_equal @workspace.id, regra.workspace_id
    assert_equal @category.id, regra.category_id
  end

  test "não cria regra sem nenhuma condição" do
    assert_no_difference -> { CategoryRule.count } do
      post workspace_category_rules_path(@workspace), params: {
        category_rule: { name: "Vazia", kind: "expense", category_id: @category.id }
      }
    end
    assert_response :unprocessable_entity
    assert_match "ao menos uma condição", @response.body
  end

  test "atualiza regra do workspace" do
    regra = CategoryRule.create!(name: "Antiga", keywords: "x", workspace: @workspace,
                                 origin: "manual", category: @category)
    patch workspace_category_rule_path(@workspace, regra), params: {
      category_rule: { name: "Nova", keywords: "y" }
    }
    assert_redirected_to workspace_category_rules_path(@workspace)
    assert_equal "Nova", regra.reload.name
  end

  test "exclui regra do workspace" do
    regra = CategoryRule.create!(name: "Excluir", keywords: "x", workspace: @workspace, origin: "manual")
    assert_difference -> { CategoryRule.count }, -1 do
      delete workspace_category_rule_path(@workspace, regra)
    end
    assert_redirected_to workspace_category_rules_path(@workspace)
  end

  test "não permite editar regra do sistema" do
    global = CategoryRule.create!(name: "Sistema", keywords: "x", origin: "seed")
    get edit_workspace_category_rule_path(@workspace, global)
    assert_redirected_to workspace_category_rules_path(@workspace)
    follow_redirect!
    assert_match "sistema não podem ser editadas", @response.body
  end

  test "não permite excluir regra do sistema" do
    global = CategoryRule.create!(name: "Sistema", keywords: "x", origin: "seed")
    assert_no_difference -> { CategoryRule.count } do
      delete workspace_category_rule_path(@workspace, global)
    end
    assert_redirected_to workspace_category_rules_path(@workspace)
  end

  test "não acessa regra de outro workspace" do
    outro    = Workspace.create!(name: "Outro", kind: "empresa", owner: @user)
    de_outro = CategoryRule.create!(name: "De outro", keywords: "x", workspace: outro, origin: "manual")
    get edit_workspace_category_rule_path(@workspace, de_outro)
    assert_response :not_found
  end
end
