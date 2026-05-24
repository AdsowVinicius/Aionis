class Document < ApplicationRecord
  belongs_to :workspace
  belongs_to :counterparty, optional: true
  has_many :financial_transactions, dependent: :nullify
  has_many :document_extractions, dependent: :destroy

  has_one_attached :file

  enum :status, {
    pending: "pending",
    processing: "processing",
    processed: "processed",
    failed: "failed",
    review: "review"
  }

  enum :source, {
    web: "web",
    email: "email",
    whatsapp: "whatsapp",
    manual: "manual"
  }

  ALLOWED_CONTENT_TYPES = %w[
    application/pdf
    image/jpeg
    image/png
    text/xml
    application/xml
  ].freeze

  MAX_FILE_SIZE = 10.megabytes

  validates :status, :source, presence: true

  def latest_extraction
    document_extractions.max_by(&:created_at)
  end
  validate  :acceptable_file

  private

  def acceptable_file
    unless file.attached?
      errors.add(:file, "deve ser anexado")
      return
    end

    unless file.blob.content_type.in?(ALLOWED_CONTENT_TYPES)
      errors.add(:file, "deve ser PDF, JPG, PNG ou XML (recebido: #{file.blob.content_type})")
    end

    if file.blob.byte_size > MAX_FILE_SIZE
      errors.add(:file, "deve ter no máximo 10 MB (enviado: #{(file.blob.byte_size / 1.megabyte.to_f).round(1)} MB)")
    end
  end
end
