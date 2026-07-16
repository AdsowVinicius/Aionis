# frozen_string_literal: true

module Aionis
  # Orquestra a extração de dados de um Document.
  #
  # Roteia por tipo de arquivo (CLAUDE.md §4):
  #   XML fiscal            -> FiscalXmlParser (parser interno)
  #   PDF/PNG/JPG/JPEG      -> OCR (Integrations.ocr) -> OcrNormalizer -> Rule Engine
  #   OCR indisponível      -> placeholder (revisão manual)
  #
  # Cria/atualiza a DocumentExtraction, ajusta o status do Document e registra
  # AuditLog. NÃO chama IA. Resiliente: erros deixam o documento em "failed"
  # sem propagar.
  #
  #   Aionis::DocumentExtractionService.call(document)
  class DocumentExtractionService
    XML_CONTENT_TYPES = %w[text/xml application/xml].freeze
    OCR_CONTENT_TYPES = %w[image/png image/jpeg image/jpg application/pdf].freeze

    PLACEHOLDER_MESSAGE =
      "Leitura automática por OCR/IA indisponível para este tipo de arquivo. " \
      "Envie o XML fiscal para extração automática, ou crie o lançamento manualmente."

    def self.call(document) = new(document).call

    def initialize(document)
      @document = document
    end

    def call
      @extraction = @document.document_extractions.create!(
        workspace_id: @document.workspace_id,
        status:       "processing",
        started_at:   Time.current
      )

      if xml?
        process_xml
      elsif ocr_candidate?
        process_ocr
      else
        process_placeholder(PLACEHOLDER_MESSAGE, provider: "placeholder")
      end

      @extraction
    rescue => e
      fail_extraction(e)
      @extraction
    end

    private

    attr_reader :document, :extraction

    def content_type
      @content_type ||= (document.file.attached? ? document.file.blob.content_type : nil)
    end

    def xml?           = content_type.in?(XML_CONTENT_TYPES)
    def ocr_candidate? = content_type.in?(OCR_CONTENT_TYPES)

    # --- XML fiscal ---

    def process_xml
      result = Aionis::FiscalXmlParser.call(document.file.download)

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
        audit_processing(provider: Aionis::FiscalXmlParser::PROCESSOR_NAME, reason: "XML sem dados extraíveis")
        return
      end

      extraction.update!(
        status:                     result.confidence >= 61 ? "extracted" : "needs_review",
        processor_name:             Aionis::FiscalXmlParser::PROCESSOR_NAME,
        processor_version:          Aionis::FiscalXmlParser::PROCESSOR_VERSION,
        confidence_score:           result.confidence,
        extracted_data:             stringify(result.fields),
        suggested_transaction_data: result.suggested_transaction_data,
        finished_at:                Time.current
      )
      document.update!(status: "review")
      audit_processing(provider: Aionis::FiscalXmlParser::PROCESSOR_NAME, reason: "XML fiscal processado")
    end

    # --- OCR (imagem/PDF) ---

    def process_ocr
      result = Aionis::Integrations.ocr.extract(
        io:           document.file.download,
        content_type: content_type,
        filename:     document.file.filename.to_s
      )

      audit_ocr(result)

      text = result.data["text"].to_s if result.success?
      return process_placeholder(PLACEHOLDER_MESSAGE, provider: result.provider) if text.blank?

      normalized = Aionis::OcrNormalizer.call(text, ocr_confidence: result.data["confidence"].to_i)
      classification = classify(normalized, extra_text: text)

      extraction.update!(
        status:                     normalized.confidence >= 61 ? "extracted" : "needs_review",
        processor_name:             result.provider,
        processor_version:          Aionis::OcrNormalizer::PROCESSOR_VERSION,
        confidence_score:           normalized.confidence,
        raw_text:                   text,
        extracted_data:             stringify(normalized.fields).merge(ocr_metadata(result, classification)),
        suggested_transaction_data: normalized.suggested_transaction_data,
        finished_at:                Time.current
      )
      document.update!(status: "review")
      audit_processing(provider: result.provider, reason: "Documento digitalizado via OCR",
                       confidence: normalized.confidence)
    end

    # Rule Engine: sugestão preliminar de categoria. Usa o texto completo do OCR
    # (extra_text) para casar palavras-chave que não estão na descrição curta.
    def classify(normalized, extra_text: nil)
      return {} unless normalized.success?

      suggestion = normalized.suggested_transaction_data
      Aionis::ClassificationEngine.new(
        workspace:   document.workspace,
        description: suggestion["description"],
        kind:        suggestion["kind"],
        tax_id:      suggestion["counterparty_tax_id_snapshot"],
        extra_text:  extra_text
      ).call
    end

    def ocr_metadata(result, classification)
      meta = {
        "ocr_provider"   => result.provider,
        "ocr_confidence" => result.data["confidence"].to_i,
        "ocr_pages"      => result.data["pages"].to_i,
        "ocr_words"      => result.data["words"].to_i
      }
      if classification.respond_to?(:category_id) && classification.category_id.present?
        meta["suggested_category_id"]       = classification.category_id
        meta["classification_confidence"]   = classification.confidence
      end
      meta
    end

    # --- Placeholder (sem extração automática) ---

    def process_placeholder(message, provider:)
      extraction.update!(
        status:            "needs_review",
        processor_name:    "placeholder",
        processor_version: "0.1",
        confidence_score:  0,
        extracted_data:    { "message" => message },
        finished_at:       Time.current
      )
      document.update!(status: "review")
      audit_processing(provider: provider, reason: "Documento sem extração automática (OCR pendente)")
    end

    # --- Auditoria ---

    def audit_ocr(result)
      AuditLog.log(
        action:     "ocr",
        origin:     "ocr",
        workspace:  document.workspace,
        document:   document,
        auditable:  document,
        provider:   result.provider,
        confidence: result.data["confidence"].to_i,
        reason:     result.success? ? "OCR concluído" : (result.message || "OCR indisponível"),
        metadata:   { content_type: content_type, status: result.status }
      )
    end

    def audit_processing(provider:, reason:, confidence: nil)
      AuditLog.log(
        action:     "document_processing",
        origin:     "job",
        workspace:  document.workspace,
        document:   document,
        auditable:  document,
        provider:   provider,
        confidence: confidence || extraction&.confidence_score,
        reason:     reason,
        metadata:   { document_status: document.status, extraction_status: extraction&.status }
      )
    end

    def fail_extraction(error)
      extraction&.update(status: "failed", error_message: error.message, finished_at: Time.current)
      document.update(status: "failed")
      audit_processing(provider: "document_extraction_service",
                       reason: "Falha no processamento: #{error.message}")
    rescue => e
      Rails.logger.error("[DocumentExtractionService] falha ao registrar erro: #{e.message}")
    end

    # JSONB exige chaves string e valores serializáveis (Date -> ISO8601).
    def stringify(fields)
      fields.each_with_object({}) do |(k, v), acc|
        acc[k.to_s] = v.is_a?(Date) ? v.iso8601 : v
      end
    end
  end
end
