# Service for extracting text from images using Tesseract OCR
class OcrService
  # Extract text from an image file using Tesseract
  # @param image_path [String] Path to the image file
  # @param language [String] Language code for Tesseract (e.g., 'por' for Portuguese, 'eng' for English)
  # @return [String] Extracted text from the image
  def self.extract_text(image_path, language: 'por')
    raise ArgumentError, "Image file not found: #{image_path}" unless File.exist?(image_path)

    begin
      result = RTesseract.new(image_path, lang: language).to_s
      result.strip
    rescue RTesseract::TesseractNotFoundError
      raise "Tesseract OCR is not installed or not found in PATH"
    rescue StandardError => e
      raise "Error extracting text from image: #{e.message}"
    end
  end

  # Extract text from an Active Storage attachment
  # @param attachment [ActiveStorage::Attachment] The attachment to process
  # @param language [String] Language code for Tesseract
  # @return [String] Extracted text
  def self.extract_from_attachment(attachment, language: 'por')
    raise ArgumentError, "Attachment is required" if attachment.blank?

    attachment.open do |file|
      extract_text(file.path, language: language)
    end
  end

  # Check if Tesseract is available
  # @return [Boolean] true if Tesseract is installed and accessible
  def self.available?
    system("tesseract --version > /dev/null 2>&1")
  end
end

