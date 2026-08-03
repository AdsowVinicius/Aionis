require "test_helper"

class Aionis::Integrations::Ai::GroqProviderTest < ActiveSupport::TestCase
  Resp = Struct.new(:code, :body)

  def provider(stdout: nil, code: 200, captured: nil, **settings)
    http = ->(method, url, headers, body) do
      captured&.merge!(method: method, url: url, headers: headers, body: JSON.parse(body))
      Resp.new(code, stdout)
    end
    base = { api_key: "gsk-test" }
    Aionis::Integrations::Ai::GroqProvider.new(base.merge(settings).merge(http: http))
  end

  # Resposta no formato OpenAI Chat Completions (o que a Groq devolve).
  def api_message(content, tool_calls: nil, finish: "stop", input: 100, output: 50)
    message = { role: "assistant", content: content }
    message[:tool_calls] = tool_calls if tool_calls
    {
      choices: [{ message: message, finish_reason: finish }],
      usage: { prompt_tokens: input, completion_tokens: output },
      model: "llama-3.3-70b-versatile"
    }.to_json
  end

  test "provider_key é groq e configured? exige api_key" do
    assert_equal "groq", provider.provider_key
    assert provider.configured?
    refute provider(api_key: "").configured?
  end

  test "classify retorna categoria, confiança e uso, e chama o endpoint da Groq" do
    captured = {}
    json = api_message('{"category_id": 7, "confidence": 82, "reasons": ["fornecedor conhecido"]}')
    result = provider(stdout: json, captured: captured).classify(context: {
      categories: [{ id: 7, name: "Transporte" }], description: "uber", kind: "expense",
      amount_cents: 2500, tax_id: nil, text: "recibo"
    })

    assert result.success?
    assert_equal 7, result.data["category_id"]
    assert_equal 82, result.data["confidence"]
    assert_includes result.data["reasons"], "fornecedor conhecido"
    assert_equal 100, result.data["usage"]["input_tokens"]
    assert_equal 50,  result.data["usage"]["output_tokens"]
    assert_operator result.data["usage"]["cost_cents"], :>, 0

    assert_equal "https://api.groq.com/openai/v1/chat/completions", captured[:url]
    assert_equal "Bearer gsk-test", captured[:headers]["authorization"]
    assert_equal "llama-3.3-70b-versatile", captured[:body]["model"]
    # A persona vai como mensagem de sistema (API estilo OpenAI).
    assert_equal "system", captured[:body]["messages"].first["role"]
  end

  test "AI_MODEL/AI_BASE_URL sobrescrevem os defaults" do
    captured = {}
    provider(stdout: api_message("{}"), captured: captured,
             model: "openai/gpt-oss-120b", base_url: "https://proxy.local/v1/")
      .classify(context: { categories: [], description: "x", kind: "expense" })

    assert_equal "openai/gpt-oss-120b", captured[:body]["model"]
    assert_equal "https://proxy.local/v1/chat/completions", captured[:url]
  end

  test "sem api_key retorna unavailable sem chamar HTTP" do
    called = false
    http = ->(*) { called = true; Resp.new(200, "{}") }
    prov = Aionis::Integrations::Ai::GroqProvider.new(api_key: "", http: http)
    assert prov.classify(context: {}).unavailable?
    assert prov.chat(messages: []).unavailable?
    refute called
  end

  test "erro HTTP vira failure com a mensagem da Groq" do
    result = provider(stdout: "boom", code: 401)
             .classify(context: { categories: [], description: "x", kind: "expense" })
    refute result.success?
    assert_equal :error, result.status
    assert_match(/Groq respondeu 401/, result.message)
  end

  test "chat traduz tools do formato Anthropic para funções OpenAI" do
    captured = {}
    tools = [{ name: "consultar_saldo", description: "Saldo atual",
               input_schema: { "type" => "object", "properties" => {} } }]
    provider(stdout: api_message("oi"), captured: captured)
      .chat(messages: [{ role: "user", content: "e aí" }], system: "Você é o Aionis", tools: tools)

    fn = captured[:body]["tools"].first
    assert_equal "function", fn["type"]
    assert_equal "consultar_saldo", fn["function"]["name"]
    assert_equal({ "type" => "object", "properties" => {} }, fn["function"]["parameters"])
    assert_equal "Você é o Aionis", captured[:body]["messages"].first["content"]
  end

  test "chat converte tool_calls da Groq em blocos tool_use (contrato Anthropic)" do
    calls = [{ id: "call_1", type: "function",
               function: { name: "consultar_gastos", arguments: '{"periodo":"esse mês"}' } }]
    result = provider(stdout: api_message(nil, tool_calls: calls, finish: "tool_calls"))
             .chat(messages: [{ role: "user", content: "quanto gastei?" }])

    assert result.success?
    assert_equal "tool_use", result.data["stop_reason"]
    block = result.data["content"].first
    assert_equal "tool_use", block["type"]
    assert_equal "call_1", block["id"]
    assert_equal "consultar_gastos", block["name"]
    assert_equal({ "periodo" => "esse mês" }, block["input"])
  end

  test "chat marca tool_use mesmo quando finish_reason vem como stop" do
    calls = [{ id: "c1", type: "function", function: { name: "consultar_saldo", arguments: "{}" } }]
    result = provider(stdout: api_message(nil, tool_calls: calls, finish: "stop"))
             .chat(messages: [{ role: "user", content: "saldo?" }])
    assert_equal "tool_use", result.data["stop_reason"]
  end

  test "chat sem tools devolve bloco de texto e stop_reason end_turn" do
    result = provider(stdout: api_message("Seu saldo é R$ 100,00"))
             .chat(messages: [{ role: "user", content: "saldo?" }])

    assert_equal "end_turn", result.data["stop_reason"]
    assert_equal [{ "type" => "text", "text" => "Seu saldo é R$ 100,00" }], result.data["content"]
  end

  test "chat reenvia o histórico de tool calling no formato OpenAI" do
    captured = {}
    history = [
      { role: "user", content: "quanto gastei?" },
      { role: "assistant", content: [
        { "type" => "text", "text" => "vou consultar" },
        { "type" => "tool_use", "id" => "call_1", "name" => "consultar_gastos", "input" => { "periodo" => "hoje" } }
      ] },
      { role: "user", content: [
        { "type" => "tool_result", "tool_use_id" => "call_1", "content" => '{"total":"R$ 10,00"}' }
      ] }
    ]
    provider(stdout: api_message("Você gastou R$ 10,00"), captured: captured).chat(messages: history)

    msgs = captured[:body]["messages"]
    assert_equal %w[user assistant tool], msgs.map { |m| m["role"] }
    call = msgs[1]["tool_calls"].first
    assert_equal "call_1", call["id"]
    assert_equal "consultar_gastos", call["function"]["name"]
    assert_equal({ "periodo" => "hoje" }, JSON.parse(call["function"]["arguments"]))
    assert_equal "call_1", msgs[2]["tool_call_id"]
    assert_equal '{"total":"R$ 10,00"}', msgs[2]["content"]
  end

  test "calcula custo a partir dos preços por 1M tokens" do
    json = api_message("{}", input: 1_000_000, output: 1_000_000)
    result = provider(stdout: json, input_price: 1.0, output_price: 5.0)
             .classify(context: { categories: [], description: "x", kind: "expense" })
    # (1.00 + 5.00) dólares = 600 centavos
    assert_in_delta 600.0, result.data["usage"]["cost_cents"], 0.01
  end
end
