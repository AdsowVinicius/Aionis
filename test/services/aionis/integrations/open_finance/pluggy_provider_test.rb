require "test_helper"

class Aionis::Integrations::OpenFinance::PluggyProviderTest < ActiveSupport::TestCase
  Resp = Struct.new(:code, :body)

  # Roteia a chamada HTTP por trecho da URL. Sempre resolve /auth primeiro.
  def http_for(routes)
    ->(_method, url, _headers, _body) do
      key = routes.keys.find { |k| url.include?(k) }
      raise "sem stub para #{url}" unless key
      r = routes[key]
      Resp.new(r[:code] || 200, (r[:json] || {}).to_json)
    end
  end

  def provider(routes, **settings)
    base = { client_id: "cid", client_secret: "secret" }
    Aionis::Integrations::OpenFinance::PluggyProvider.new(base.merge(settings).merge(http: http_for(routes)))
  end

  AUTH = { "auth" => { json: { apiKey: "AK123" } } }.freeze

  test "provider_key é pluggy e configured? exige client_id e secret" do
    p = provider(AUTH)
    assert_equal "pluggy", p.provider_key
    assert p.configured?
    refute provider(AUTH, client_id: "").configured?
  end

  test "create_consent retorna connect_token e redirect_url" do
    p = provider(AUTH.merge("connect_token" => { json: { accessToken: "TK9" } }))
    r = p.create_consent(workspace_id: 1, redirect_url: nil)
    assert r.success?
    assert_equal "TK9", r.data["connect_token"]
    assert_includes r.data["redirect_url"], "TK9"
  end

  test "fetch_accounts normaliza contas" do
    routes = AUTH.merge("accounts" => { json: { results: [
      { "id" => "acc1", "name" => "Conta", "type" => "BANK", "subtype" => "CHECKING_ACCOUNT",
        "number" => "123", "currencyCode" => "BRL", "balance" => 1500.50,
        "bankData" => { "name" => "Banco X", "branch" => "0001" } }
    ] } })
    r = provider(routes).fetch_accounts(consent_id: "item1")
    acc = r.data["accounts"].first
    assert_equal "acc1", acc["external_id"]
    assert_equal "checking", acc["kind"]
    assert_equal 150_050, acc["balance_cents"]
    assert_equal "Banco X", acc["institution"]
  end

  test "fetch_transactions normaliza valor, direção e data" do
    routes = AUTH.merge("transactions" => { json: { results: [
      { "id" => "t1", "amount" => -50.0, "type" => "DEBIT",
        "date" => "2026-07-10T00:00:00.000Z", "description" => "COMPRA" }
    ] } })
    r = provider(routes).fetch_transactions(account_id: "acc1", from: "2026-01-01", to: "2026-07-16")
    tx = r.data["transactions"].first
    assert_equal 5_000, tx["amount_cents"]
    assert_equal "debit", tx["direction"]
    assert_equal "2026-07-10", tx["date"]
    assert_equal "COMPRA", tx["description"]
  end

  test "revoke_consent chama DELETE e retorna sucesso" do
    r = provider(AUTH.merge("items" => { code: 200, json: {} })).revoke_consent(consent_id: "item1")
    assert r.success?
  end

  test "falha de autenticação propaga erro" do
    r = provider({ "auth" => { code: 401, json: { message: "bad" } } }).fetch_accounts(consent_id: "x")
    refute r.success?
  end

  test "sem configuração retorna unavailable" do
    p = Aionis::Integrations::OpenFinance::PluggyProvider.new(client_id: "", client_secret: "")
    assert p.fetch_accounts(consent_id: "x").unavailable?
  end
end
