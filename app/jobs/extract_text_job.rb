# Background job to extract text from images using OCR
class ExtractTextJob < ApplicationJob
  queue_as :default

  # Extract text from an image and save to a designated field/record
  # @param record_type [String] Class name of the record to update
  # @param record_id [Integer] ID of the record
  # @param attachment_field [String] Name of the attachment field (e.g., 'image', 'document')
  # @param output_field [String] Name of the field to store extracted text (e.g., 'extracted_text')
  # @param language [String] Tesseract language code
  def perform(record_type, record_id, attachment_field, output_field, language = 'por')
    record = record_type.constantize.find(record_id)
    attachment = record.send(attachment_field)

    unless attachment.present? && attachment.attached?
      return Rails.logger.warn("No attachment found for #{record_type} #{record_id}")
    end

    begin
      extracted_text = OcrService.extract_from_attachment(attachment, language: language)
      record.update(output_field => extracted_text)
      Rails.logger.info("Text extracted successfully from #{record_type} #{record_id}: #{extracted_text.length} characters")
    rescue => e
      Rails.logger.error("OCR extraction failed for #{record_type} #{record_id}: #{e.message}")
      raise
    end
  end
end

