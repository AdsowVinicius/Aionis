class ProcessDocumentJob < ApplicationJob
  queue_as :default

  XML_CONTENT_TYPES = %w[text/xml application/xml].freeze

  def perform(document_id)
    document = Document.find_by(id: document_id)
    return unless document

    document.update!(status: "processing")

    extraction = document.document_extractions.create!(
      workspace_id: document.workspace_id,
      status:       "processing",
      started_at:   Time.current
    )

    if xml_document?(document)
      process_xml(document, extraction)
    else
      process_placeholder(document, extraction)
    end
  rescue => e
    extraction&.update(status: "failed", error_message: e.message, finished_at: Time.current)
    document&.update(status: "failed")
  end

  private

  def xml_document?(document)
    document.file.attached? &&
      document.file.blob.content_type.in?(XML_CONTENT_TYPES)
  end

  def process_xml(document, extraction)
    xml    = document.file.download
    result = Aionis::FiscalXmlParser.call(xml)

    unless result.success?
      extraction.update!(
        status:            "needs_review",
        processor_name:    Aionis::FiscalXmlParser::PROCESSOR_NAME,
        processor_version: Aionis::FiscalXmlParser::PROCESSOR_VERSION,
        confidence_score:  result.confidence,
        extracted_data:    { "message" => result.error || "Não foi possível extrair dados do XML." },
        finished_at:       Time.current
      )
      document.update!(status: "review")
      return
    end

    # Faixas de confiança do CLAUDE.md: 86-100 alta, 61-85 média, 0-60 baixa.
    # No MVP mantemos revisão humana em todos os casos (documento fica "review"),
    # mas o status da extração reflete a confiança.
    extraction_status = result.confidence >= 61 ? "extracted" : "needs_review"

    extraction.update!(
      status:                     extraction_status,
      processor_name:             Aionis::FiscalXmlParser::PROCESSOR_NAME,
      processor_version:          Aionis::FiscalXmlParser::PROCESSOR_VERSION,
      confidence_score:           result.confidence,
      extracted_data:             stringify(result.fields),
      suggested_transaction_data: result.suggested_transaction_data,
      finished_at:                Time.current
    )

    document.update!(status: "review")
  end

  def process_placeholder(document, extraction)
    # PDF/imagem ainda sem OCR/IA — pipeline fundação apenas.
    extraction.update!(
      status:            "needs_review",
      processor_name:    "placeholder",
      processor_version: "0.1",
      confidence_score:  0,
      extracted_data: {
        "message" => "Leitura automática por OCR/IA ainda não implementada para " \
                     "este tipo de arquivo. Envie o XML fiscal para extração automática, " \
                     "ou crie o lançamento manualmente."
      },
      finished_at: Time.current
    )

    document.update!(status: "review")
  end

  # JSONB exige chaves string e valores serializáveis (Date -> ISO8601).
  def stringify(fields)
    fields.each_with_object({}) do |(k, v), acc|
      acc[k.to_s] = v.is_a?(Date) ? v.iso8601 : v
    end
  end
end
