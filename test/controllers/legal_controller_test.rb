require "test_helper"

class LegalControllerTest < ActionDispatch::IntegrationTest
  # A Meta valida a URL da política antes de aprovar o app do WhatsApp: ela
  # PRECISA responder 200 para quem não tem conta. Se alguém puser um
  # authenticate_user! global de novo, este teste quebra.
  test "política de privacidade é pública (sem login)" do
    get privacy_policy_path
    assert_response :success
    assert_match(/Política de Privacidade/, response.body)
    assert_match(/LGPD/, response.body)
  end

  test "apelidos de URL redirecionam para a rota canônica" do
    [ "/politicas-privacidade", "/privacidade" ].each do |apelido|
      get apelido
      assert_redirected_to "/politica-de-privacidade"
    end
  end

  test "dados do controlador vêm do config (nada hardcoded na view)" do
    config = YAML.load_file(Rails.root.join("config/aionis/legal.yml"))
    get privacy_policy_path
    assert_includes response.body, config["dpo_email"]
    assert_includes response.body, config["whatsapp_number"]
  end

  test "avisa que é rascunho enquanto os dados da empresa não forem preenchidos" do
    config = YAML.load_file(Rails.root.join("config/aionis/legal.yml"))
    get privacy_policy_path

    if config["company_tax_id"].to_s.start_with?("PENDENTE")
      assert_match(/não publique ainda/i, response.body)
    else
      refute_match(/não publique ainda/i, response.body)
    end
  end

  test "cobre os pontos exigidos pela LGPD e pela Meta" do
    get privacy_policy_path

    %w[WhatsApp inteligência\ artificial Cookies ANPD].each do |termo|
      assert_match(/#{Regexp.escape(termo)}/i, response.body, "faltou a seção sobre #{termo}")
    end
    assert_match(/direitos/i, response.body)
    assert_match(/transferência internacional/i, response.body)
  end
end
