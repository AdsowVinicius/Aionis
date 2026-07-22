require "test_helper"

class Aionis::Agent::ConversationTest < ActiveSupport::TestCase
  # Provedor de IA fake com roteiro: cada chamada devolve o próximo item.
  # Registra as chamadas para inspecionar system/messages/tools enviados.
  class FakeAi
    attr_reader :calls

    def initialize(*script)
      @script = script
      @calls  = []
    end

    def configured? = true

    def chat(messages:, system: nil, tools: [], model: nil, max_tokens: nil)
      @calls << { messages: messages.deep_dup, system: system, tools: tools }
      data = @script.shift || FakeAi.text("acabou o roteiro")
      Aionis::Integrations::Result.ok(provider: "anthropic", data: data)
    end

    def self.text(body)
      { "content" => [{ "type" => "text", "text" => body }], "stop_reason" => "end_turn" }
    end

    def self.tool_use(name, input = {}, id: "tu_#{SecureRandom.hex(3)}")
      { "content" => [{ "type" => "tool_use", "id" => id, "name" => name, "input" => input }],
        "stop_reason" => "tool_use" }
    end
  end

  setup do
    @user = User.create!(name: "C", email: "conv_#{SecureRandom.hex(4)}@t.test", password: "senha1234")
    @workspace = Workspace.create!(name: "WS", kind: "empresa", owner: @user)
    @workspace.financial_transactions.create!(
      kind: "income", description: "Venda", amount_cents: 50_000,
      origin: "manual", status: "confirmed", transacted_on: Date.current
    )
  end

  teardown { Aionis::Integrations.reset! }

  def with_ai(fake)
    Aionis::Integrations.override(:ai, fake)
    yield fake
  end

  def converse(message, channel: "portal")
    Aionis::Agent::Conversation.call(workspace: @workspace, message: message, channel: channel)
  end

  test "loop de tool calling: executa a tool no backend e devolve a resposta final" do
    fake = FakeAi.new(
      FakeAi.tool_use("consultar_saldo", { "periodo" => "esse mês" }),
      FakeAi.text("Seu saldo do mês é R$ 500,00.")
    )
    with_ai(fake) do
      reply = converse("qual meu saldo?")
      assert reply.success?
      assert_equal "Seu saldo do mês é R$ 500,00.", reply.text
      assert_equal ["consultar_saldo"], reply.tools_used
      assert_equal 2, reply.iterations

      # A 2ª chamada recebeu o tool_result com dados REAIS do backend
      second = fake.calls.last[:messages]
      tool_result = second.last[:content].first
      assert_equal "tool_result", tool_result[:type]
      assert_includes tool_result[:content], "R$ 500,00"
    end
  end

  test "respeita o teto de 5 iterações" do
    fake = FakeAi.new(*Array.new(8) { FakeAi.tool_use("consultar_saldo") })
    with_ai(fake) do
      reply = converse("pergunta infinita")
      assert_equal 5, fake.calls.size, "deveria parar exatamente em MAX_ITERATIONS"
      assert_equal Aionis::Agent::Conversation::FALLBACK_MAX_ITER, reply.text
    end
  end

  test "usa janela deslizante de histórico, nunca a conversa inteira" do
    30.times do |i|
      @workspace.agent_messages.create!(channel: "portal", role: i.even? ? "user" : "assistant", content: "msg #{i}")
    end

    with_ai(FakeAi.new(FakeAi.text("ok"))) do |fake|
      converse("mensagem atual")
      sent = fake.calls.first[:messages]
      window = Aionis::Agent::Conversation::HISTORY_WINDOW
      assert_operator sent.size, :<=, window
      texts = sent.map { |m| m[:content].to_s }.join("\n")
      assert_includes texts, "mensagem atual"
      refute_includes texts, "msg 0", "mensagens antigas não devem entrar"
    end
  end

  test "pergunta fora do escopo: sem tool, resposta graciosa (sem erro, sem query)" do
    fake = FakeAi.new(FakeAi.text("Eu cuido das suas finanças no Aionis! Posso consultar saldo, gastos e contas."))
    with_ai(fake) do
      assert_no_difference -> { FinancialTransaction.count } do
        reply = converse("qual a previsão do dólar amanhã?")
        assert reply.success?
        assert_empty reply.tools_used
        assert_match(/finanças/i, reply.text)
      end
    end
  end

  test "IA não configurada devolve fallback indisponível sem quebrar" do
    Aionis::Integrations.reset! # volta ao NullProvider (test env)
    reply = converse("oi")
    refute reply.success?
    assert_equal Aionis::Agent::Conversation::FALLBACK_UNAVAILABLE, reply.text
  end

  test "system prompt inclui o cartão de memória do workspace" do
    WorkspaceMemory.remember!(@workspace, key: "ramo", value: "construção civil", relevance: 90)
    with_ai(FakeAi.new(FakeAi.text("ok"))) do |fake|
      converse("oi")
      assert_includes fake.calls.first[:system], "construção civil"
    end
  end

  test "persiste as mensagens e audita a conversa" do
    with_ai(FakeAi.new(FakeAi.text("resposta"))) do
      assert_difference -> { @workspace.agent_messages.count }, 2 do # user + assistant
        converse("pergunta")
      end
      assert AuditLog.where(workspace_id: @workspace.id, origin: "ai")
                     .where("reason LIKE ?", "Conversa do agente%").exists?
    end
  end

  test "tool desconhecida pedida pela LLM vira tool_result de erro, não exceção" do
    fake = FakeAi.new(
      FakeAi.tool_use("dropar_banco", { "tabela" => "users" }),
      FakeAi.text("desculpe, não posso")
    )
    with_ai(fake) do
      reply = converse("hackeia aí")
      assert reply.success?
      tool_result = fake.calls.last[:messages].last[:content].first
      assert_includes tool_result[:content], "desconhecida"
    end
  end

  test "a API key nunca aparece nas mensagens nem no system prompt" do
    with_ai(FakeAi.new(FakeAi.text("ok"))) do |fake|
      converse("oi")
      payload = fake.calls.first.to_s
      refute_includes payload, "sk-ant", "API key não pode vazar no payload"
    end
  end
end
