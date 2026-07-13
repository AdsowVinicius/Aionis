require "test_helper"

# Garante que todo provedor Base define o contrato (levanta NotImplementedError)
# e que todo NullProvider responde de forma segura ("unavailable") sem chamadas
# externas. Assim, adicionar um provedor concreto novo é seguro: se ele esquecer
# de implementar um método do contrato, o comportamento herdado falha alto.
class Aionis::Integrations::ProvidersTest < ActiveSupport::TestCase
  Result = Aionis::Integrations::Result

  # [ base, null, [ [metodo, kwargs], ... ] ]
  CONTRACTS = [
    [
      Aionis::Integrations::Whatsapp::Base,
      Aionis::Integrations::Whatsapp::NullProvider,
      [
        [:send_text,      { to: "5511999", body: "oi" }],
        [:send_template,  { to: "5511999", name: "welcome" }],
        [:parse_inbound,  [{}]],
        [:verify_webhook, { mode: "subscribe", token: "t", challenge: "c" }]
      ]
    ],
    [
      Aionis::Integrations::OpenFinance::Base,
      Aionis::Integrations::OpenFinance::NullProvider,
      [
        [:create_consent,     { workspace_id: 1, redirect_url: "http://x" }],
        [:fetch_accounts,     { consent_id: "c1" }],
        [:fetch_transactions, { account_id: "a1", from: Date.today, to: Date.today }],
        [:revoke_consent,     { consent_id: "c1" }]
      ]
    ],
    [
      Aionis::Integrations::Ocr::Base,
      Aionis::Integrations::Ocr::NullProvider,
      [
        [:extract, { io: StringIO.new("x"), content_type: "image/png" }]
      ]
    ],
    [
      Aionis::Integrations::Ai::Base,
      Aionis::Integrations::Ai::NullProvider,
      [
        [:classify, { context: {} }],
        [:review,   { context: {} }],
        [:complete, { prompt: "oi" }]
      ]
    ]
  ].freeze

  def invoke(provider, method, args)
    if args.is_a?(Array)
      provider.public_send(method, *args)
    else
      provider.public_send(method, **args)
    end
  end

  CONTRACTS.each do |base_class, null_class, methods|
    methods.each do |method, args|
      test "#{base_class}##{method} levanta NotImplementedError (contrato)" do
        assert_raises(NotImplementedError) { invoke(base_class.new, method, args) }
      end

      test "#{null_class}##{method} retorna Result indisponível sem chamada externa" do
        result = invoke(null_class.new, method, args)
        assert_instance_of Result, result
        assert_not result.success?
        assert result.unavailable?
        assert_equal "null", result.provider
        assert result.message.present?
      end
    end

    test "#{null_class} não está configurado" do
      assert_not null_class.new.configured?
    end
  end

  test "provider_key deriva a chave do nome da classe" do
    assert_equal "null", Aionis::Integrations::Ocr::NullProvider.new.provider_key
  end

  test "settings são simbolizadas na construção" do
    provider = Aionis::Integrations::Ai::NullProvider.new("model" => "x")
    assert_equal "x", provider.settings[:model]
  end
end
