require "test_helper"

class Workspaces::WhatsappChannelsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(name: "Ch", email: "ch_#{SecureRandom.hex(4)}@t.test", password: "senha1234")
    @workspace = Workspace.create!(name: "WS", kind: "empresa", owner: @user)
    sign_in @user
  end

  test "index lista os canais do workspace" do
    @workspace.workspace_channels.create!(provider: "meta_cloud", phone_number_id: "PN1", status: "connected")
    get workspace_whatsapp_channels_path(@workspace)
    assert_response :success
    assert_match "PN1", @response.body
  end

  test "conecta um canal Meta" do
    assert_difference -> { WorkspaceChannel.count }, 1 do
      post workspace_whatsapp_channels_path(@workspace), params: {
        workspace_channel: {
          provider: "meta_cloud", phone_number_id: "PN123",
          display_phone_number: "+55 11 90000-0000", access_token: "TOKEN", verify_token: "vt"
        }
      }
    end
    assert_redirected_to workspace_whatsapp_channels_path(@workspace)
    channel = @workspace.workspace_channels.find_by(phone_number_id: "PN123")
    assert channel.connected?
    assert_equal "TOKEN", channel.access_token
  end

  test "não conecta Meta sem phone_number_id" do
    assert_no_difference -> { WorkspaceChannel.count } do
      post workspace_whatsapp_channels_path(@workspace), params: {
        workspace_channel: { provider: "meta_cloud", access_token: "TOKEN" }
      }
    end
    assert_response :unprocessable_entity
  end

  test "editar mantém o token quando access_token vem em branco" do
    channel = @workspace.workspace_channels.create!(provider: "meta_cloud", phone_number_id: "PN9", access_token: "OLD", status: "connected")
    patch workspace_whatsapp_channel_path(@workspace, channel), params: {
      workspace_channel: { provider: "meta_cloud", phone_number_id: "PN9", display_phone_number: "+55 11 91111-1111", access_token: "" }
    }
    assert_redirected_to workspace_whatsapp_channels_path(@workspace)
    channel.reload
    assert_equal "OLD", channel.access_token
    assert_equal "+55 11 91111-1111", channel.display_phone_number
  end

  test "remove um canal" do
    channel = @workspace.workspace_channels.create!(provider: "meta_cloud", phone_number_id: "PN5")
    assert_difference -> { WorkspaceChannel.count }, -1 do
      delete workspace_whatsapp_channel_path(@workspace, channel)
    end
  end

  test "não acessa canal de outro workspace" do
    other = Workspace.create!(name: "Outro", kind: "empresa", owner: @user)
    channel = other.workspace_channels.create!(provider: "meta_cloud", phone_number_id: "PNX")
    get edit_workspace_whatsapp_channel_path(@workspace, channel)
    assert_response :not_found
  end
end
