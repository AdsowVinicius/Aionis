require "test_helper"

class WhatsappModelsTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(name: "WA", email: "wa_#{SecureRandom.hex(4)}@t.test", password: "senha1234")
    @workspace = Workspace.create!(name: "WS WA", kind: "empresa", owner: @user)
    @channel = @workspace.workspace_channels.create!(instance: "inst_#{SecureRandom.hex(3)}", provider: "evolution")
  end

  test "WorkspaceChannel exige instance única" do
    dup = @workspace.workspace_channels.build(instance: @channel.instance, provider: "evolution")
    refute dup.valid?
    assert_includes dup.errors.attribute_names, :instance
  end

  test "IncomingMessage deduplica por canal + wa_message_id" do
    @channel.incoming_messages.create!(workspace: @workspace, wa_message_id: "M1", kind: "text")
    dup = @channel.incoming_messages.build(workspace: @workspace, wa_message_id: "M1", kind: "text")
    refute dup.valid?
  end

  test "IncomingMessage#media? reconhece documento/imagem" do
    msg = @channel.incoming_messages.new(kind: "document")
    assert msg.media?
    assert_not @channel.incoming_messages.new(kind: "text").media?
  end

  test "OutgoingMessage transita para sent e failed" do
    out = @channel.outgoing_messages.create!(workspace: @workspace, to_number: "5511999", body: "oi")
    assert out.pending?
    out.mark_sent!("X1")
    assert out.sent?
    assert_equal "X1", out.provider_message_id
    assert_not_nil out.sent_at

    out2 = @channel.outgoing_messages.create!(workspace: @workspace, to_number: "5511999", body: "oi")
    out2.mark_failed!("erro qualquer")
    assert out2.failed?
    assert_equal "erro qualquer", out2.error
  end

  test "workspace destrói canais e mensagens em cascata" do
    @channel.incoming_messages.create!(workspace: @workspace, wa_message_id: "Z1", kind: "text")
    @channel.outgoing_messages.create!(workspace: @workspace, to_number: "5511", body: "x")
    assert_difference -> { WorkspaceChannel.count } => -1,
                      -> { IncomingMessage.count } => -1,
                      -> { OutgoingMessage.count } => -1 do
      @workspace.destroy
    end
  end
end
