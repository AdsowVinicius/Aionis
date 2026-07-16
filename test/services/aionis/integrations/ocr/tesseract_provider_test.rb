require "test_helper"

class Aionis::Integrations::Ocr::TesseractProviderTest < ActiveSupport::TestCase
  # Runner injetado: captura o argv e devolve uma saída canned, sem tocar em
  # python/tesseract reais.
  def provider(stdout: "", stderr: "", code: 0, captured: nil)
    runner = ->(argv) do
      captured&.replace(argv)
      [stdout, stderr, code]
    end
    Aionis::Integrations::Ocr::TesseractProvider.new(runner: runner)
  end

  test "provider_key é tesseract" do
    assert_equal "tesseract", provider.provider_key
  end

  test "extrai texto e confiança em caso de sucesso" do
    json = { text: "TOTAL 12,00", confidence: 87, pages: 1, words: 2 }.to_json
    result = provider(stdout: json).extract(io: "bytes", content_type: "image/png")

    assert result.success?
    assert_equal "tesseract", result.provider
    assert_equal "TOTAL 12,00", result.data["text"]
    assert_equal 87, result.data["confidence"]
    assert_equal 1, result.data["pages"]
  end

  test "exit code de dependência retorna unavailable" do
    json = { error: "No module named 'cv2'", error_type: "dependency" }.to_json
    result = provider(stdout: json, code: 3).extract(io: "x", content_type: "application/pdf")

    assert result.unavailable?
    refute result.success?
  end

  test "exit code de erro retorna failure com mensagem" do
    json = { error: "imagem corrompida", error_type: "processing" }.to_json
    result = provider(stdout: json, code: 1).extract(io: "x", content_type: "image/jpeg")

    refute result.success?
    assert_equal :error, result.status
    assert_match "imagem corrompida", result.message
  end

  test "tipo de conteúdo não suportado retorna unavailable sem chamar o worker" do
    chamado = false
    runner  = ->(_argv) { chamado = true; ["", "", 0] }
    prov = Aionis::Integrations::Ocr::TesseractProvider.new(runner: runner)

    result = prov.extract(io: "x", content_type: "text/xml")
    assert result.unavailable?
    refute chamado, "o worker não deve ser invocado para tipo não suportado"
  end

  test "monta argv com arquivo, content-type, lang e dpi" do
    captured = []
    prov = provider(stdout: { text: "ok", confidence: 10 }.to_json, captured: captured)
    prov.extract(io: "x", content_type: "image/png")

    assert_includes captured, "--content-type"
    assert_includes captured, "image/png"
    assert_includes captured, "--lang"
    assert_includes captured, "por"
    assert_includes captured, "--dpi"
    assert_includes captured, "200"
    # há um --file seguido de um caminho de arquivo temporário
    idx = captured.index("--file")
    assert idx, "argv deve conter --file"
    assert captured[idx + 1].to_s.end_with?(".png")
  end

  test "mapeia jpeg para extensão .jpg no arquivo temporário" do
    captured = []
    prov = provider(stdout: { text: "ok", confidence: 10 }.to_json, captured: captured)
    prov.extract(io: "x", content_type: "image/jpeg")
    idx = captured.index("--file")
    assert captured[idx + 1].to_s.end_with?(".jpg")
  end
end
