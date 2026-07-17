require "test_helper"

class Aionis::Ai::ClassifierTest < ActiveSupport::TestCase
  class FakeAi
    def initialize(category_id:, confidence: 75)
      @category_id = category_id
      @confidence = confidence
    end
    def configured? = true
    def classify(context:)
      Aionis::Integrations::Result.ok(provider: "anthropic", data: {
        "category_id" => @category_id, "confidence" => @confidence,
        "reasons" => ["fornecedor conhecido"], "prompt" => "p", "response" => "r",
        "model" => "claude-haiku-4-5",
        "usage" => { "input_tokens" => 100, "output_tokens" => 50,
                     "cost_cents" => 0.06, "duration_ms" => 120, "model" => "claude-haiku-4-5" }
      })
    end
  end

  setup do
    @user = User.create!(name: "AI", email: "ai_#{SecureRandom.hex(4)}@t.test", password: "senha1234")
    @workspace = Workspace.create!(name: "WS AI", kind: "empresa", owner: @user)
    @category = Category.create!(name: "Transporte #{SecureRandom.hex(2)}", kind: "expense",
                                 cost_type: "variable", essentiality: "operational_important")
  end

  teardown { Aionis::Integrations.reset! }

  test "classifier retorna sugestão da IA e registra AiInteraction + AuditLog" do
    Aionis::Integrations.override(:ai, FakeAi.new(category_id: @category.id, confidence: 82))

    suggestion = nil
    assert_difference -> { AiInteraction.count }, 1 do
      suggestion = Aionis::Ai::Classifier.call(context: {
        workspace: @workspace, description: "corrida de app", kind: "expense"
      })
    end

    assert_equal "ai", suggestion.source
    assert_equal @category.id, suggestion.category_id
    assert_equal 82, suggestion.confidence

    interaction = AiInteraction.last
    assert_equal "anthropic", interaction.provider
    assert_equal 150, interaction.total_tokens
    assert_operator interaction.cost_cents, :>, 0
    assert AuditLog.where(action: "ai", origin: "ai").exists?
  end

  test "provider não configurado não chama IA" do
    # sem override → provider null (configured? false)
    assert_no_difference -> { AiInteraction.count } do
      assert_nil Aionis::Ai::Classifier.call(context: { workspace: @workspace, description: "x", kind: "expense" })
    end
  end

  # --- Gate no ClassificationEngine ---

  test "engine aciona IA quando sem regra e allow_ai=true" do
    Aionis::Integrations.override(:ai, FakeAi.new(category_id: @category.id))
    s = Aionis::ClassificationEngine.new(
      workspace: @workspace, description: "algo sem regra alguma", kind: "expense", allow_ai: true
    ).call
    assert_equal "ai", s.source
    assert_equal @category.id, s.category_id
  end

  test "engine NÃO aciona IA sem allow_ai" do
    Aionis::Integrations.override(:ai, FakeAi.new(category_id: @category.id))
    s = Aionis::ClassificationEngine.new(workspace: @workspace, description: "algo", kind: "expense").call
    assert_equal "none", s.source
    assert_equal 0, AiInteraction.count
  end

  test "engine NÃO aciona IA quando o Rule Engine acerta" do
    CategoryRule.create!(name: "Aluguel", keywords: "aluguel", kind: "expense",
                         category: @category, workspace: @workspace, confidence: 70)
    Aionis::Integrations.override(:ai, FakeAi.new(category_id: @category.id))

    s = Aionis::ClassificationEngine.new(
      workspace: @workspace, description: "pagamento de aluguel", kind: "expense", allow_ai: true
    ).call
    assert_equal "rule", s.source
    assert_equal 0, AiInteraction.count
  end
end
