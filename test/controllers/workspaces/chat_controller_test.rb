require "test_helper"

class Workspaces::ChatControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  # IA fake: sempre responde um texto fixo (sem tools).
  class FakeAi
    def configured? = true
    def chat(messages:, system: nil, tools: [], model: nil, max_tokens: nil)
      Aionis::Integrations::Result.ok(provider: "anthropic", data: {
        "content" => [{ "type" => "text", "text" => "Resposta do agente no portal" }],
        "stop_reason" => "end_turn"
      })
    end
  end

  setup do
    @user = User.create!(name: "Chat", email: "chat_#{SecureRandom.hex(4)}@t.test", password: "senha1234")
    @workspace = Workspace.create!(name: "WS Chat", kind: "empresa", owner: @user)
    sign_in @user
  end

  teardown { Aionis::Integrations.reset! }

  test "GET show renderiza o chat" do
    get workspace_chat_path(@workspace)
    assert_response :success
    assert_match(/Assistente financeiro/, response.body)
  end

  test "POST create passa pelo MESMO orquestrador e devolve turbo_stream" do
    Aionis::Integrations.override(:ai, FakeAi.new)

    post workspace_chat_path(@workspace),
         params: { message: "qual meu saldo?" },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_match(/Resposta do agente no portal/, response.body)
    # Persistiu user + assistant no canal portal
    assert_equal %w[user assistant], @workspace.agent_messages.for_channel("portal").chronological.pluck(:role)
  end

  test "POST create com mensagem vazia só redireciona (nada persiste)" do
    assert_no_difference -> { AgentMessage.count } do
      post workspace_chat_path(@workspace), params: { message: "  " }
    end
    assert_redirected_to workspace_chat_path(@workspace)
  end

  test "workspace de outro usuário é bloqueado" do
    intruder = User.create!(name: "I", email: "intr_#{SecureRandom.hex(4)}@t.test", password: "senha1234")
    sign_in intruder

    get workspace_chat_path(@workspace)
    assert_redirected_to workspaces_path

    assert_no_difference -> { AgentMessage.count } do
      post workspace_chat_path(@workspace), params: { message: "me dá os dados do outro" }
    end
  end
end
