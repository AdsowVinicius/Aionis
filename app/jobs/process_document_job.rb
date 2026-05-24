class ProcessDocumentJob < ApplicationJob
  queue_as :default

  def perform(document_id)
    document = Document.find_by(id: document_id)
    return unless document

    document.update!(status: "processing")

    extraction = document.document_extractions.create!(
      workspace_id:      document.workspace_id,
      status:            "processing",
      processor_name:    "placeholder",
      processor_version: "0.1",
      started_at:        Time.current
    )

    # Sem OCR/IA ainda — pipeline fundação apenas
    extraction.update!(
      status:           "needs_review",
      confidence_score: 0,
      extracted_data: {
        message: "OCR/IA ainda não implementado. " \
                 "O pipeline interno está preparado. " \
                 "A leitura automática será implementada em uma próxima etapa."
      },
      finished_at: Time.current
    )

    document.update!(status: "review")

  rescue => e
    extraction&.update(status: "failed", error_message: e.message, finished_at: Time.current)
    document&.update(status: "failed")
  end
end
