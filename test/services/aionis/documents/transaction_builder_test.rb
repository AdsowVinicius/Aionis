require "test_helper"

class Aionis::Documents::TransactionBuilderTest < ActiveSupport::TestCase
  setup do
    @user      = User.create!(name: "TB", email: "tb_#{SecureRandom.hex(4)}@aionis.test", password: "senha1234")
    @workspace = Workspace.create!(name: "WS TB", kind: "empresa", owner: @user)
  end

  def document_with(confidence:, source: "web", suggestion: default_suggestion)
    doc = @workspace.documents.new(source: source, status: "review")
    doc.save!(validate: false)
    doc.document_extractions.create!(
      workspace: @workspace, status: "extracted",
      confidence_score: confidence, raw_text: "TOTAL 120,00",
      suggested_transaction_data: suggestion
    )
    doc
  end

  def default_suggestion
    {
      "kind" => "expense", "description" => "Compra no mercado",
      "amount_cents" => 12_000, "transacted_on" => Date.current.iso8601,
      "counterparty_name_snapshot" => "Mercado do Bairro"
    }
  end

  test "constrói lançamento não salvo a partir da extração" do
    doc = document_with(confidence: 70)
    tx  = Aionis::Documents::TransactionBuilder.build(doc)

    assert tx.new_record?
    assert_equal 12_000,      tx.amount_cents
    assert_equal "expense",   tx.kind
    assert_equal "document",  tx.origin
    assert_equal doc.id,      tx.document_id
    assert_equal "Compra no mercado", tx.description
  end

  test "status padrão é pending na faixa média" do
    tx = Aionis::Documents::TransactionBuilder.build(document_with(confidence: 70))
    assert_equal "pending", tx.status
  end

  test "status padrão é confirmed na faixa alta" do
    tx = Aionis::Documents::TransactionBuilder.build(document_with(confidence: 90))
    assert_equal "confirmed", tx.status
  end

  test "status explícito sobrepõe o padrão" do
    tx = Aionis::Documents::TransactionBuilder.build(document_with(confidence: 90), status: "pending")
    assert_equal "pending", tx.status
  end

  test "retorna nil quando não há valor sugerido" do
    doc = document_with(confidence: 0, suggestion: { "kind" => "expense" })
    assert_nil Aionis::Documents::TransactionBuilder.build(doc)
  end

  test "expõe a confiança da extração" do
    builder = Aionis::Documents::TransactionBuilder.new(document_with(confidence: 42))
    assert_equal 42, builder.confidence
  end

  test "descrição padrão difere entre WhatsApp e web" do
    doc = document_with(confidence: 90, source: "whatsapp", suggestion: { "kind" => "expense", "amount_cents" => 5_000 })
    tx  = Aionis::Documents::TransactionBuilder.build(doc)
    assert_equal "Comprovante via WhatsApp", tx.description
  end

  test "lançamento construído é válido para salvar" do
    tx = Aionis::Documents::TransactionBuilder.build(document_with(confidence: 90))
    assert tx.save, tx.errors.full_messages.to_sentence
  end
end
