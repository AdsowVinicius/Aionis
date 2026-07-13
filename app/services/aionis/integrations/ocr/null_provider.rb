# frozen_string_literal: true

module Aionis
  module Integrations
    module Ocr
      # Provedor padrão sem OCR real. Retorna "indisponível" para que o
      # ProcessDocumentJob mantenha o documento em revisão manual sem quebrar.
      class NullProvider < Base
        def extract(io:, content_type:, filename: nil) = unavailable
      end
    end
  end
end
