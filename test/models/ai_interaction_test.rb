require "test_helper"

class AiInteractionTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(name: "AI", email: "aii_#{SecureRandom.hex(4)}@t.test", password: "senha1234")
    @workspace = Workspace.create!(name: "WS", kind: "empresa", owner: @user)
  end

  test "exige provider e kind válido" do
    i = AiInteraction.new(workspace: @workspace, kind: "classification")
    refute i.valid?
    assert_includes i.errors.attribute_names, :provider

    i.provider = "anthropic"
    i.kind = "xpto"
    refute i.valid?
  end

  test "total_tokens soma entrada e saída" do
    i = AiInteraction.new(tokens_input: 100, tokens_output: 50)
    assert_equal 150, i.total_tokens
  end

  test "grava custo, tokens e metadados" do
    i = AiInteraction.create!(workspace: @workspace, provider: "anthropic", kind: "classification",
                              tokens_input: 100, tokens_output: 50, cost_cents: 0.06,
                              duration_ms: 120, confidence: 82, metadata: { category_id: 3 })
    assert i.persisted?
    assert_equal 3, i.reload.metadata["category_id"]
  end
end
