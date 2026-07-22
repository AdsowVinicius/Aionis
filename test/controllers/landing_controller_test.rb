require "test_helper"

class LandingControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "root renderiza a landing sem autenticação" do
    get root_path
    assert_response :success
    assert_match(/PREÇO DE FUNDADOR/, response.body)
    assert_match(/Manda no WhatsApp/, response.body)
  end

  test "números vêm do config (nada hardcoded na view)" do
    config = YAML.load_file(Rails.root.join("config/aionis/landing.yml"))
    get root_path
    assert_includes response.body, config["price_now"]
    assert_includes response.body, config["price_after"]
    assert_includes response.body, config["pain_per_month"]
  end

  test "vagas de fundador refletem workspaces reais (total - count)" do
    user = User.create!(name: "L", email: "land_#{SecureRandom.hex(4)}@t.test", password: "senha1234")
    Workspace.create!(name: "WS1", kind: "mei", owner: user)
    Workspace.create!(name: "WS2", kind: "cpf", owner: user)

    get root_path
    expected = 500 - Workspace.count
    assert_includes response.body, ">#{expected}</b>"
  end

  test "formulários de captura apontam para o cadastro Devise" do
    get root_path
    assert_select "form[action=?][method=get]", new_user_registration_path, count: 2 do
      assert_select "input[type=email][name=email]"
    end
  end

  test "SEO: title, meta description e Open Graph presentes" do
    get root_path
    assert_select "title", /Aionis/
    assert_select "meta[name=description]"
    assert_select "meta[property='og:title']"
    assert_select "meta[property='og:description']"
    assert_select "meta[property='og:image']"
  end

  test "não usa CDN de Tailwind nem de Lucide" do
    get root_path
    refute_includes response.body, "cdn.tailwindcss.com"
    refute_includes response.body, "unpkg.com"
    assert_match(/lucide\.min[^"]*\.js/, response.body) # vendorado via Propshaft
  end

  test "usuário logado no root NÃO vê a landing (rota authenticated intercepta)" do
    user = User.create!(name: "L2", email: "land2_#{SecureRandom.hex(4)}@t.test", password: "senha1234")
    sign_in user
    get root_path
    # dashboard#index responde (ou redireciona p/ criar workspace) — nunca a landing
    assert_includes [200, 302], response.status
    refute_match(/PREÇO DE FUNDADOR/, response.body.to_s)
  end

  test "cadastro Devise pré-preenche o e-mail vindo da landing" do
    get new_user_registration_path(email: "lead@exemplo.com")
    assert_response :success
    assert_select "input[name='user[email]'][value='lead@exemplo.com']"
  end
end
