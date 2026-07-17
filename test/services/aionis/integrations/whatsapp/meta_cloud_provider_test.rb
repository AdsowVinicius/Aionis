require "test_helper"

class Aionis::Integrations::Whatsapp::MetaCloudProviderTest < ActiveSupport::TestCase
  Resp = Struct.new(:code, :body)

  def provider(routes: {}, captured: nil, **settings)
    http = ->(method, url, headers, body) do
      captured&.merge!(method: method, url: url, headers: headers, body: body)
      key = routes.keys.find { |k| url.include?(k) }
      r = key ? routes[key] : { code: 200, body: "{}" }
      Resp.new(r[:code] || 200, r[:body])
    end
    base = { app_secret: "app", verify_token: "vt", graph_version: "v21.0", base_url: "http://graph.test" }
    Aionis::Integrations::Whatsapp::MetaCloudProvider.new(base.merge(settings).merge(http: http))
  end

  CRED = { access_token: "tok", phone_number_id: "PN" }.freeze

  test "provider_key é meta_cloud e configured? exige app_secret" do
    assert_equal "meta_cloud", provider.provider_key
    assert provider.configured?
    refute provider(app_secret: "").configured?
  end

  test "send_text posta no phone_number_id e retorna message_id" do
    captured = {}
    p = provider(routes: { "/PN/messages" => { code: 200, body: { messages: [{ id: "wamid1" }] }.to_json } }, captured: captured)
    r = p.send_text(to: "5511999", body: "olá", credentials: CRED)

    assert r.success?
    assert_equal "wamid1", r.data["message_id"]
    assert_equal "http://graph.test/v21.0/PN/messages", captured[:url]
    assert_equal "Bearer tok", captured[:headers]["Authorization"]
    assert_equal "text", JSON.parse(captured[:body])["type"]
  end

  test "send sem credenciais retorna unavailable" do
    assert provider.send_text(to: "x", body: "y", credentials: {}).unavailable?
  end

  test "send_document e send_image montam o tipo correto" do
    captured = {}
    p = provider(routes: { "/PN/messages" => { body: { messages: [{ id: "d1" }] }.to_json } }, captured: captured)
    p.send_document(to: "5511", media: { link: "http://f/x.pdf" }, caption: "nf", credentials: CRED)
    body = JSON.parse(captured[:body])
    assert_equal "document", body["type"]
    assert_equal "nf", body["document"]["caption"]
  end

  test "mark_as_read envia status read" do
    captured = {}
    p = provider(routes: { "/PN/messages" => { body: "{}" } }, captured: captured)
    r = p.mark_as_read(message_id: "wamid1", credentials: CRED)
    assert r.success?
    assert_equal "read", JSON.parse(captured[:body])["status"]
  end

  test "parse_inbound normaliza mensagem de imagem" do
    payload = { "entry" => [{ "changes" => [{ "value" => {
      "metadata" => { "phone_number_id" => "PN" },
      "contacts" => [{ "profile" => { "name" => "João" } }],
      "messages" => [{ "id" => "m1", "from" => "5511999", "type" => "image",
                       "image" => { "id" => "media1", "mime_type" => "image/jpeg" } }]
    } }] }] }
    d = provider.parse_inbound(payload).data
    assert_equal "message", d["event"]
    assert_equal "image", d["type"]
    assert_equal "media1", d["media"]["id"]
    assert_equal "PN", d["phone_number_id"]
    assert_equal "João", d["push_name"]
  end

  test "parse_inbound reconhece status de entrega" do
    payload = { "entry" => [{ "changes" => [{ "value" => {
      "statuses" => [{ "id" => "wamid1", "status" => "delivered" }]
    } }] }] }
    d = provider.parse_inbound(payload).data
    assert_equal "status", d["event"]
    assert_equal "delivered", d["status"]
  end

  test "download_media resolve url e baixa binário" do
    routes = {
      "/media1" => { body: { url: "http://cdn.test/file" }.to_json },
      "cdn.test" => { body: "BINARY" }
    }
    r = provider(routes: routes).download_media({ "id" => "media1", "mimetype" => "image/png" }, credentials: CRED)
    assert r.success?
    assert_equal "BINARY", r.data["bytes"]
    assert_equal "image/png", r.data["mimetype"]
  end

  test "verify_webhook valida handshake" do
    assert provider.verify_webhook(mode: "subscribe", token: "vt", challenge: "abc").success?
    refute provider.verify_webhook(mode: "subscribe", token: "errado", challenge: "abc").success?
  end

  test "verify_signature valida HMAC do app secret" do
    raw = '{"a":1}'
    good = "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", "app", raw)
    assert provider.verify_signature(raw_body: raw, signature: good).success?
    refute provider.verify_signature(raw_body: raw, signature: "sha256=zzz").success?
  end

  test "429 vira falha transitória (pending) para retry" do
    p = provider(routes: { "/PN/messages" => { code: 429, body: "rate" } })
    r = p.send_text(to: "5511", body: "x", credentials: CRED)
    refute r.success?
    assert_equal :pending, r.status
  end
end
