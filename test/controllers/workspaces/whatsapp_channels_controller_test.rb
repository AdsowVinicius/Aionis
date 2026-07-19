require "test_helper"

class Workspaces::WhatsappChannelsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(name: "Ch", email: "ch_#{SecureRandom.hex(4)}@t.test", password: "senha1234")
    @workspace = Workspace.create!(name: "WS", kind: "empresa", owner: @user)
    sign_in @user
  end

  test "index mostra o painel de WhatsApp (somente leitura)" do
    get workspace_whatsapp_channels_path(@workspace)
    assert_response :success
    assert_match(/WhatsApp/i, @response.body)
  end

  test "index exibe o número já cadastrado do workspace" do
    @workspace.update!(whatsapp_number: "5511988887777")
    get workspace_whatsapp_channels_path(@workspace)
    assert_response :success
    assert_match "5511988887777", @response.body
  end

  test "registrar número (via update) normaliza e salva no workspace" do
    patch workspace_path(@workspace), params: { workspace: { whatsapp_number: "55 (11) 98888-7777" } }
    assert_equal "5511988887777", @workspace.reload.whatsapp_number
  end

  test "painel não oferece mais conexão manual de canal" do
    get workspace_whatsapp_channels_path(@workspace)
    assert_response :success
    assert_no_match(/Conectar canal/, @response.body)
  end
end
