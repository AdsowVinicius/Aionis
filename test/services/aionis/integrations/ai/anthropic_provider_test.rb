require "test_helper"

class Aionis::Integrations::Ai::AnthropicProviderTest < ActiveSupport::TestCase
  Resp = Struct.new(:code, :body)

  def provider(stdout: nil, code: 200, captured: nil, **settings)
    http = ->(method, url, headers, body) do
      captured&.merge!(method: method, url: url, headers: headers, body: JSON.parse(body))
      Resp.new(code, stdout)
    end
    base = { api_key: "sk-test", model: "claude-haiku-4-5", input_price: 1.0, output_price: 5.0 }
    Aionis::Integrations::Ai::AnthropicProvider.new(base.merge(settings).merge(http: http))
  end

  def api_message(text, input: 100, output: 50)
    { content: [{ type: "text", text: text }],
      usage: { input_tokens: input, output_tokens: output },
      model: "claude-haiku-4-5" }.to_json
  end

  test "provider_key é anthropic e configured? exige api_key" do
    assert_equal "anthropic", provider.provider_key
    assert provider.configured?
    refute provider(api_key: "").configured?
  end

  test "classify retorna categoria, confiança e uso" do
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
    # envia x-api-key e version
    assert_equal "sk-test", captured[:headers]["x-api-key"]
    assert_equal "2023-06-01", captured[:headers]["anthropic-version"]
  end

  test "clampa confiança e tolera JSON com texto ao redor" do
    json = api_message('Claro! {"category_id": null, "confidence": 150, "reasons": []} pronto.')
    result = provider(stdout: json).classify(context: { categories: [], description: "x", kind: "expense" })
    assert_equal 100, result.data["confidence"]
    assert_nil result.data["category_id"]
  end

  test "sem api_key retorna unavailable sem chamar HTTP" do
    called = false
    http = ->(*) { called = true; Resp.new(200, "{}") }
    prov = Aionis::Integrations::Ai::AnthropicProvider.new(api_key: "", http: http)
    assert prov.classify(context: {}).unavailable?
    refute called
  end

  test "erro HTTP vira failure" do
    result = provider(stdout: "boom", code: 500).classify(context: { categories: [], description: "x", kind: "expense" })
    refute result.success?
    assert_equal :error, result.status
  end

  test "calcula custo a partir dos preços por 1M tokens" do
    json = api_message("{}", input: 1_000_000, output: 1_000_000)
    result = provider(stdout: json, input_price: 1.0, output_price: 5.0)
             .classify(context: { categories: [], description: "x", kind: "expense" })
    # (1.00 + 5.00) dólares = 600 centavos
    assert_in_delta 600.0, result.data["usage"]["cost_cents"], 0.01
  end
end
