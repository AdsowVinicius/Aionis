require "test_helper"

class Aionis::Whatsapp::SendMessageJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  class OkProvider
    def send_text(to:, body:, instance: nil)
      Aionis::Integrations::Result.ok(provider: "evolution", data: { "message_id" => "OUT9" })
    end
  end

  class FailProvider
    def send_text(to:, body:, instance: nil)
      Aionis::Integrations::Result.error(provider: "evolution", message: "offline")
    end
  end

  setup do
    @user = User.create!(name: "S", email: "send_#{SecureRandom.hex(4)}@t.test", password: "senha1234")
    @workspace = Workspace.create!(name: "WS", kind: "empresa", owner: @user)
    @channel = @workspace.workspace_channels.create!(instance: "aionis", provider: "evolution")
    @out = @channel.outgoing_messages.create!(workspace: @workspace, to_number: "5511999", body: "oi")
  end

  teardown { Aionis::Integrations.reset! }

  test "envio bem-sucedido marca sent com provider_message_id" do
    Aionis::Integrations.override(:whatsapp, OkProvider.new)
    Aionis::Whatsapp::SendMessageJob.new.perform(@out.id)

    @out.reload
    assert @out.sent?
    assert_equal "OUT9", @out.provider_message_id
    assert_equal 1, @out.attempts
  end

  test "mensagem já enviada não é reenviada" do
    @out.mark_sent!("PREV")
    Aionis::Integrations.override(:whatsapp, OkProvider.new)
    Aionis::Whatsapp::SendMessageJob.new.perform(@out.id)
    assert_equal 0, @out.reload.attempts
  end

  test "falha de envio levanta DeliveryError e conta tentativa" do
    Aionis::Integrations.override(:whatsapp, FailProvider.new)
    job = Aionis::Whatsapp::SendMessageJob.new

    assert_raises(Aionis::Whatsapp::DeliveryError) { job.perform(@out.id) }
    @out.reload
    assert @out.pending?
    assert_equal 1, @out.attempts
  end

  test "após esgotar as tentativas, marca como failed" do
    Aionis::Integrations.override(:whatsapp, FailProvider.new)

    perform_enqueued_jobs do
      Aionis::Whatsapp::SendMessageJob.perform_later(@out.id)
    end

    @out.reload
    assert @out.failed?, "deveria falhar após esgotar os retries"
    assert_operator @out.attempts, :>=, 3
  end
end
