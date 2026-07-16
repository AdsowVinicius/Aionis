require "test_helper"

class Aionis::Integrations::Whatsapp::EvolutionProviderTest < ActiveSupport::TestCase
  Resp = Struct.new(:code, :body)

  def provider(http: nil, **settings)
    base = { base_url: "http://evo.test", api_key: "KEY", webhook_token: "sec", instance: "aionis" }
    Aionis::Integrations::Whatsapp::EvolutionProvider.new(base.merge(settings).merge(http: http))
  end

  test "provider_key é evolution e configured? exige base_url e api_key" do
    assert_equal "evolution", provider.provider_key
    assert provider.configured?
    refute provider(base_url: "", api_key: "").configured?
  end

  test "send_text envia texto e retorna message_id" do
    captured = {}
    http = ->(method, url, headers, body) do
      captured[:method] = method
      captured[:url]    = url
      captured[:body]   = JSON.parse(body)
      captured[:apikey] = headers["apikey"]
      Resp.new(201, { key: { id: "OUT123" } }.to_json)
    end

    result = provider(http: http).send_text(to: "5511999999999", body: "olá", instance: "aionis")

    assert result.success?
    assert_equal "OUT123", result.data["message_id"]
    assert_equal :post, captured[:method]
    assert_equal "http://evo.test/message/sendText/aionis", captured[:url]
    assert_equal "5511999999999", captured[:body]["number"]
    assert_equal "olá", captured[:body]["text"]
    assert_equal "KEY", captured[:apikey]
  end

  test "send_text propaga erro HTTP" do
    http = ->(*) { Resp.new(500, "boom") }
    result = provider(http: http).send_text(to: "551199", body: "x")
    refute result.success?
    assert_equal :error, result.status
  end

  test "parse_inbound normaliza mensagem de texto" do
    payload = {
      "event" => "messages.upsert", "instance" => "aionis",
      "data" => {
        "key" => { "remoteJid" => "5511988887777@s.whatsapp.net", "fromMe" => false, "id" => "M1" },
        "pushName" => "João", "message" => { "conversation" => "oi" },
        "messageTimestamp" => 1_700_000_000
      }
    }
    d = provider.parse_inbound(payload).data
    assert_equal "text", d["type"]
    assert_equal "5511988887777", d["from"]
    assert_equal "M1", d["wa_message_id"]
    assert_equal "oi", d["text"]
    assert_equal "João", d["push_name"]
  end

  test "parse_inbound reconhece documento com mídia" do
    payload = {
      "event" => "messages.upsert", "instance" => "aionis",
      "data" => {
        "key" => { "remoteJid" => "551199@s.whatsapp.net", "fromMe" => false, "id" => "M2" },
        "message" => { "documentMessage" => { "mimetype" => "application/pdf", "fileName" => "nota.pdf" } },
        "messageType" => "documentMessage"
      }
    }
    d = provider.parse_inbound(payload).data
    assert_equal "document", d["type"]
    assert_equal "application/pdf", d["media"]["mimetype"]
    assert_equal "nota.pdf", d["media"]["filename"]
  end

  test "parse_inbound ignora mensagem própria e eventos irrelevantes" do
    own = { "event" => "messages.upsert", "instance" => "a",
            "data" => { "key" => { "fromMe" => true, "id" => "x" }, "message" => {} } }
    assert_equal "ignored", provider.parse_inbound(own).data["type"]

    other = { "event" => "presence.update", "instance" => "a", "data" => {} }
    assert_equal "ignored", provider.parse_inbound(other).data["type"]
  end

  test "download_media usa base64 embutido sem chamar HTTP" do
    called = false
    http = ->(*) { called = true; Resp.new(200, "{}") }
    media = { "mimetype" => "image/png", "filename" => "r.png", "base64" => Base64.encode64("hello") }

    result = provider(http: http).download_media(media, instance: "aionis")

    assert result.success?
    assert_equal "hello", result.data["bytes"]
    refute called
  end

  test "download_media busca base64 via API quando ausente" do
    http = ->(method, url, headers, body) do
      assert_equal "http://evo.test/chat/getBase64FromMediaMessage/aionis", url
      Resp.new(200, { base64: Base64.encode64("world") }.to_json)
    end
    media = { "mimetype" => "image/jpeg", "key" => { "id" => "M3" } }

    result = provider(http: http).download_media(media, instance: "aionis")
    assert_equal "world", result.data["bytes"]
  end

  test "verify_webhook valida token com comparação segura" do
    assert provider.verify_webhook(token: "sec").success?
    refute provider.verify_webhook(token: "errado").success?
    refute provider.verify_webhook(token: nil).success?
    assert provider(webhook_token: "").verify_webhook(token: "x").unavailable?
  end
end
