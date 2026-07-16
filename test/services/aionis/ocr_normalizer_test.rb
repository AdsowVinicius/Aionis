require "test_helper"

class Aionis::OcrNormalizerTest < ActiveSupport::TestCase
  SAMPLE = <<~TXT
    SUPERMERCADO BOM PRECO LTDA
    CNPJ: 11.222.333/0001-81
    Rua das Flores, 100
    Data: 15/07/2026
    Item A .... 8,00
    Item B .... 4,00
    TOTAL R$ 12,00
  TXT

  test "extrai valor total, data e CNPJ válido" do
    r = Aionis::OcrNormalizer.call(SAMPLE, ocr_confidence: 90)

    assert r.success?
    assert_equal 1_200, r.fields[:amount_cents]
    assert_equal Date.new(2026, 7, 15), r.fields[:issued_on]
    assert_equal "11222333000181", r.fields[:tax_id]
    assert_equal "cnpj", r.fields[:tax_id_type]
  end

  test "monta suggested_transaction_data no contrato do pipeline" do
    s = Aionis::OcrNormalizer.call(SAMPLE, ocr_confidence: 90).suggested_transaction_data

    assert_equal "expense", s["kind"]
    assert_equal 1_200, s["amount_cents"]
    assert_equal "2026-07-15", s["transacted_on"]
    assert_equal "informed", s["counterparty_tax_id_status"]
    assert_match "SUPERMERCADO", s["counterparty_name_snapshot"]
    assert_match(/33\/0001-81\z/, s["counterparty_tax_id_snapshot"])
  end

  test "prefere o valor da linha TOTAL" do
    r = Aionis::OcrNormalizer.call(SAMPLE, ocr_confidence: 50)
    assert_equal 1_200, r.fields[:amount_cents]
  end

  test "confiança escala com a confiança do OCR" do
    alta  = Aionis::OcrNormalizer.call(SAMPLE, ocr_confidence: 100).confidence
    baixa = Aionis::OcrNormalizer.call(SAMPLE, ocr_confidence: 20).confidence
    assert_operator alta, :>, baixa
    assert_operator alta, :<=, 100
  end

  test "texto vazio falha sem quebrar" do
    r = Aionis::OcrNormalizer.call("   ", ocr_confidence: 0)
    refute r.success?
    assert_equal 0, r.confidence
    assert r.error.present?
  end

  test "CPF/CNPJ ausente não impede extração do valor" do
    r = Aionis::OcrNormalizer.call("Padaria Central\nTOTAL 5,50", ocr_confidence: 80)
    assert r.success?
    assert_equal 550, r.fields[:amount_cents]
    assert_nil r.fields[:tax_id]
    assert_equal "not_informed", r.suggested_transaction_data["counterparty_tax_id_status"]
  end
end
