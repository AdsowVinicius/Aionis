# frozen_string_literal: true

require "json"
require "open3"
require "tempfile"
require "timeout"

module Aionis
  module Integrations
    module Ocr
      # Provedor de OCR real (OpenCV + Tesseract) via worker Python.
      #
      # Delega o pré-processamento e a leitura a script/ocr/tesseract_worker.py
      # (grayscale -> deskew -> noise removal -> contrast -> threshold -> Tesseract).
      # Este provedor apenas orquestra: grava o arquivo, invoca o worker, lê o
      # JSON e devolve um Result padrão. NÃO chama IA.
      #
      # Degrada com segurança: se python/tesseract/worker faltarem, devolve
      # `unavailable` (o pipeline mantém o documento em revisão manual). Ativação:
      # OCR_PROVIDER=tesseract em config/aionis/integrations.yml.
      #
      # Testável: o executor do shell é injetável via settings[:runner] —
      # um callable ->(argv) { [stdout, stderr, exit_code] }.
      class TesseractProvider < Base
        SUPPORTED = {
          "image/png"       => ".png",
          "image/jpeg"      => ".jpg",
          "image/jpg"       => ".jpg",
          "application/pdf" => ".pdf"
        }.freeze

        DEPENDENCY_EXIT = 3

        def configured?
          File.exist?(worker_path)
        end

        def extract(io:, content_type:, filename: nil)
          ext = SUPPORTED[content_type.to_s]
          return unavailable("Tipo não suportado pelo OCR: #{content_type}") unless ext

          with_tempfile(io, ext) do |path|
            stdout, stderr, code = run_worker(path, content_type)
            build_result(stdout, stderr, code)
          end
        rescue Timeout::Error
          Result.error(provider: provider_key, message: "OCR excedeu o tempo limite (#{timeout}s)")
        rescue => e
          Result.error(provider: provider_key, message: "Falha no OCR: #{e.message}")
        end

        private

        def build_result(stdout, stderr, code)
          case code
          when 0
            payload = JSON.parse(stdout.to_s)
            Result.ok(
              provider: provider_key,
              data: {
                "text"       => payload["text"].to_s,
                "confidence" => payload["confidence"].to_i,
                "pages"      => payload["pages"].to_i,
                "words"      => payload["words"].to_i,
                "blocks"     => []
              }
            )
          when DEPENDENCY_EXIT
            unavailable("Dependências de OCR ausentes (#{error_message(stdout, stderr)})")
          else
            Result.error(provider: provider_key, message: error_message(stdout, stderr))
          end
        end

        def error_message(stdout, stderr)
          parsed = JSON.parse(stdout.to_s) rescue nil
          parsed&.dig("error").presence || stderr.to_s.strip.presence || "erro desconhecido no OCR"
        end

        # Executa o worker. Usa o runner injetado (testes) ou Open3 com timeout.
        def run_worker(path, content_type)
          argv = [
            python_bin, worker_path,
            "--file", path,
            "--content-type", content_type.to_s,
            "--lang", lang,
            "--dpi", dpi.to_s
          ]

          if runner
            runner.call(argv)
          else
            Timeout.timeout(timeout) do
              stdout, stderr, status = Open3.capture3(*argv)
              [stdout, stderr, status.exitstatus]
            end
          end
        end

        def with_tempfile(io, ext)
          file = Tempfile.new(["aionis_ocr", ext])
          file.binmode
          file.write(io.respond_to?(:read) ? io.read : io.to_s)
          file.flush
          yield file.path
        ensure
          file&.close
          file&.unlink
        end

        def runner      = settings[:runner]
        def python_bin  = settings.fetch(:python_bin, "python3").to_s
        def lang        = settings.fetch(:lang, "por").to_s
        def dpi         = settings.fetch(:dpi, 200)
        def timeout     = settings.fetch(:timeout, 30).to_i

        def worker_path
          settings[:worker_path].presence ||
            Rails.root.join("script", "ocr", "tesseract_worker.py").to_s
        end
      end
    end
  end
end
