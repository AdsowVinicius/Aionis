require "test_helper"

class Aionis::Whatsapp::ChannelConnectorTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(name: "C", email: "conn_#{SecureRandom.hex(4)}@t.test", password: "senha1234")
    @workspace = Workspace.create!(name: "WS", kind: "empresa", owner: @user)
  end

  test "conecta um canal Meta com credenciais criptografadas" do
    channel = Aionis::Whatsapp::ChannelConnector.connect(
      @workspace, provider: "meta_cloud",
      phone_number_id: "PN123", business_account_id: "BA1",
      display_phone_number: "+55 11 99999-0000", access_token: "SECRET_TOKEN", verify_token: "vt"
    )

    assert channel.persisted?
    assert channel.connected?
    assert channel.active?
    assert_equal "PN123", channel.phone_number_id
    assert_equal "SECRET_TOKEN", channel.access_token
    # token não fica em claro no banco
    raw = ActiveRecord::Base.connection.select_value(
      "SELECT access_token FROM workspace_channels WHERE id = #{channel.id}"
    )
    refute_equal "SECRET_TOKEN", raw
    assert AuditLog.where(action: "integration", workspace_id: @workspace.id).exists?
  end

  test "conectar de novo o mesmo phone_number_id atualiza (não duplica)" do
    Aionis::Whatsapp::ChannelConnector.connect(@workspace, provider: "meta_cloud", phone_number_id: "PN9", access_token: "t1")
    assert_no_difference -> { WorkspaceChannel.count } do
      Aionis::Whatsapp::ChannelConnector.connect(@workspace, provider: "meta_cloud", phone_number_id: "PN9", access_token: "t2")
    end
    assert_equal "t2", @workspace.workspace_channels.find_by(phone_number_id: "PN9").access_token
  end

  test "rotaciona credenciais do canal" do
    channel = Aionis::Whatsapp::ChannelConnector.connect(@workspace, provider: "meta_cloud", phone_number_id: "PN2", access_token: "old")
    Aionis::Whatsapp::ChannelConnector.new(@workspace).rotate(channel, access_token: "new", refresh_token: "r1")

    channel.reload
    assert_equal "new", channel.access_token
    assert_equal "r1", channel.refresh_token
  end
end
