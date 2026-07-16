class ProcessDocumentJob < ApplicationJob
  queue_as :default

  # Enfileira/dispara a extração de um documento. A lógica de roteamento
  # (XML / OCR / placeholder), atualização de status e auditoria vive em
  # Aionis::DocumentExtractionService — o job apenas orquestra.
  def perform(document_id)
    document = Document.find_by(id: document_id)
    return unless document

    document.update!(status: "processing")
    Aionis::DocumentExtractionService.call(document)
  rescue => e
    Rails.logger.error("[ProcessDocumentJob] falha inesperada: #{e.class}: #{e.message}")
    document&.update(status: "failed")
  end
end
