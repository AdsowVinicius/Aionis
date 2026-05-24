class DocumentExtraction < ApplicationRecord
  belongs_to :workspace
  belongs_to :document

  enum :status, {
    pending:      "pending",
    processing:   "processing",
    extracted:    "extracted",
    needs_review: "needs_review",
    failed:       "failed"
  }

  validates :status, presence: true
  validate  :workspace_matches_document

  private

  def workspace_matches_document
    return if document.nil? || workspace_id.nil?
    return if document.workspace_id == workspace_id

    errors.add(:workspace_id, "deve ser o mesmo workspace do documento")
  end
end
