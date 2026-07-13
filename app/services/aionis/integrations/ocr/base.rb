# frozen_string_literal: true

module Aionis
  module Integrations
    module Ocr
      # Contrato de um provedor de OCR (ex.: worker Python com OpenCV + Tesseract,
      # ou serviço externo). Consumidor natural: ProcessDocumentJob para PDFs
      # escaneados e imagens. NÃO implementado nesta etapa.
      class Base < BaseProvider
        # Extrai texto de um documento.
        # @param io [IO, String] conteúdo binário do arquivo
        # @param content_type [String] ex.: "image/jpeg", "application/pdf"
        # @return [Result] data: { text:, blocks: [], confidence: 0..100 }
        def extract(io:, content_type:, filename: nil)
          not_implemented!(:extract)
        end
      end
    end
  end
end
