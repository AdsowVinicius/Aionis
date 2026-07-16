require "test_helper"

class Aionis::OpenFinance::ConsentServiceTest < ActiveSupport::TestCase
  class FakeOF
    def provider_key = "pluggy"
    def create_consent(workspace_id:, redirect_url:)
      Aionis::Integrations::Result.ok(provider: "pluggy",
        data: { "connect_token" => "TK", "redirect_url" => "https://connect?ct=TK", "expires_at" => nil })
    end
    def revoke_consent(consent_id:)
      Aionis::Integrations::Result.ok(provider: "pluggy", data: {})
    end
  end

  setup do
    @user = User.create!(name: "C", email: "consent_#{SecureRandom.hex(4)}@t.test", password: "senha1234")
    @workspace = Workspace.create!(name: "WS", kind: "empresa", owner: @user)
    Aionis::Integrations.override(:open_finance, FakeOF.new)
  end

  teardown { Aionis::Integrations.reset! }

  test "create inicia consentimento pendente com connect token" do
    consent = Aionis::OpenFinance::ConsentService.create(@workspace)
    assert consent.pending?
    assert_equal "TK", consent.connect_token
    assert_equal "pluggy", consent.provider
    assert AuditLog.where(action: "integration", workspace_id: @workspace.id).exists?
  end

  test "activate marca ativo com external_id" do
    svc = Aionis::OpenFinance::ConsentService.new(@workspace)
    consent = svc.create
    svc.activate(consent, external_id: "item9")
    assert consent.reload.active?
    assert_equal "item9", consent.external_id
  end

  test "revoke revoga o consentimento" do
    svc = Aionis::OpenFinance::ConsentService.new(@workspace)
    consent = svc.create
    svc.activate(consent, external_id: "item9")
    svc.revoke(consent)
    assert consent.reload.revoked?
    assert_not_nil consent.revoked_at
  end
end
