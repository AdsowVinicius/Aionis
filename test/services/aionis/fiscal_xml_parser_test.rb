require "test_helper"

class Aionis::FiscalXmlParserTest < ActiveSupport::TestCase
  NFE_PATH = Rails.root.join("test/fixtures/files/sample_nfe.xml")

  def nfe_xml
    File.read(NFE_PATH)
  end

  test "extrai valor total da NF-e em centavos" do
    result = Aionis::FiscalXmlParser.call(nfe_xml)
    assert result.success?
    assert_equal 15_000, result.fields[:amount_cents]
  end

  test "extrai data de emissao" do
    result = Aionis::FiscalXmlParser.call(nfe_xml)
    assert_equal Date.new(2024, 1, 15), result.fields[:issued_on]
  end

  test "extrai nome e CNPJ do emitente" do
    result = Aionis::FiscalXmlParser.call(nfe_xml)
    assert_equal "Loja do Bairro Comercio LTDA", result.fields[:counterparty_name]
    assert_equal "11222333000181", result.fields[:tax_id]
    assert_equal "cnpj", result.fields[:tax_id_type]
  end

  test "extrai itens do documento" do
    result = Aionis::FiscalXmlParser.call(nfe_xml)
    assert_includes result.fields[:items], "Material de escritorio"
    assert_includes result.fields[:items], "Papel A4 resma"
  end

  test "confianca alta para NF-e completa e CNPJ valido" do
    result = Aionis::FiscalXmlParser.call(nfe_xml)
    assert_equal 100, result.confidence
  end

  test "monta suggested_transaction_data pronto para lancamento" do
    result = Aionis::FiscalXmlParser.call(nfe_xml)
    s = result.suggested_transaction_data
    assert_equal "expense", s["kind"]
    assert_equal 15_000,    s["amount_cents"]
    assert_equal "2024-01-15", s["transacted_on"]
    assert_equal "Loja do Bairro Comercio LTDA", s["counterparty_name_snapshot"]
    assert_equal "informed", s["counterparty_tax_id_status"]
    assert s["counterparty_tax_id_snapshot"].present?
    assert s["description"].present?
  end

  test "kind pode ser sobrescrito (ex: nota de venda = income)" do
    result = Aionis::FiscalXmlParser.call(nfe_xml, default_kind: "income")
    assert_equal "income", result.suggested_transaction_data["kind"]
  end

  test "XML nao fiscal retorna falha sem levantar excecao" do
    result = Aionis::FiscalXmlParser.call("<foo><bar>x</bar></foo>")
    assert_not result.success?
    assert_equal 0, result.confidence
    assert result.error.present?
  end

  test "XML malformado nao levanta excecao" do
    result = Aionis::FiscalXmlParser.call("isto nao e xml <<<")
    assert_not result.success?
  end

  test "CPF/CNPJ ausente nao faz o parsing falhar" do
    xml = nfe_xml.sub(%r{<CNPJ>11222333000181</CNPJ>}, "")
    result = Aionis::FiscalXmlParser.call(xml)
    assert result.success?, "parsing deve continuar mesmo sem CPF/CNPJ"
    assert_nil result.fields[:tax_id]
    assert_equal "not_informed", result.suggested_transaction_data["counterparty_tax_id_status"]
    # sem tax_id valido: 50 (valor) + 20 (data) + 20 (nome) = 90
    assert_equal 90, result.confidence
  end

  test "CPF/CNPJ invalido marca status invalid" do
    xml = nfe_xml.sub("11222333000181", "11111111111111")
    result = Aionis::FiscalXmlParser.call(xml)
    assert result.success?
    assert_equal "invalid", result.suggested_transaction_data["counterparty_tax_id_status"]
  end
end
