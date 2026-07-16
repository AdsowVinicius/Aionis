# frozen_string_literal: true

module Aionis
  # Normalizador de texto bruto de OCR em campos estruturados de lançamento.
  #
  # É o passo "Normalizer" do pipeline de OCR: recebe o texto reconhecido e a
  # confiança do Tesseract e extrai valor, data, CPF/CNPJ e fornecedor via
  # regex/heurísticas (sem IA). Devolve um Result no MESMO contrato do
  # FiscalXmlParser, para que o restante do pipeline (prefill + Rule Engine)
  # funcione sem alterações.
  #
  # CPF/CNPJ é desejável mas NUNCA obrigatório: a ausência não faz o passo falhar.
  #
  #   result = Aionis::OcrNormalizer.call(text, ocr_confidence: 88)
  #   result.suggested_transaction_data
  class OcrNormalizer
    PROCESSOR_NAME    = "ocr_tesseract"
    PROCESSOR_VERSION = "1.0"

    MONEY_RE = /(\d{1,3}(?:\.\d{3})*,\d{2}|\d+,\d{2})/
    DATE_BR  = %r{\b(\d{2})/(\d{2})/(\d{2,4})\b}
    DATE_ISO = /\b(\d{4})-(\d{2})-(\d{2})\b/
    CNPJ_RE  = %r{\b\d{2}\.?\d{3}\.?\d{3}/?\d{4}-?\d{2}\b}
    CPF_RE   = /\b\d{3}\.?\d{3}\.?\d{3}-?\d{2}\b/

    Result = Struct.new(
      :success, :confidence, :fields, :suggested_transaction_data, :error,
      keyword_init: true
    ) do
      def success? = success
    end

    def initialize(text, ocr_confidence: 0, default_kind: "expense")
      @text           = text.to_s
      @ocr_confidence = ocr_confidence.to_i.clamp(0, 100)
      @default_kind   = default_kind
    end

    def self.call(text, **opts) = new(text, **opts).call

    def call
      return failure("OCR não retornou texto") if @text.strip.blank?

      fields = extract_fields
      Result.new(
        success:    fields[:amount_cents].present?,
        confidence: score(fields),
        fields:     fields,
        suggested_transaction_data: build_suggestion(fields),
        error:      nil
      )
    rescue => e
      failure("Falha ao normalizar texto do OCR: #{e.message}")
    end

    private

    def extract_fields
      tax_id, tax_id_type = extract_tax_id
      {
        amount_cents:      extract_amount,
        issued_on:         extract_date,
        counterparty_name: extract_counterparty_name,
        tax_id:            tax_id,
        tax_id_type:       tax_id_type,
        ocr_confidence:    @ocr_confidence
      }
    end

    # Prefere o valor na linha que menciona "total"; senão o maior valor achado.
    def extract_amount
      total_line = lines.find { |l| l.match?(/total/i) && l.match?(MONEY_RE) }
      candidate  = total_line&.match(MONEY_RE)&.captures&.first
      candidate ||= @text.scan(MONEY_RE).flatten.max_by { |m| money_to_cents(m) }
      candidate ? money_to_cents(candidate) : nil
    end

    def extract_date
      if (m = @text.match(DATE_BR))
        d, mth, y = m.captures
        y = "20#{y}" if y.length == 2
        safe_date(y.to_i, mth.to_i, d.to_i)
      elsif (m = @text.match(DATE_ISO))
        y, mth, d = m.captures
        safe_date(y.to_i, mth.to_i, d.to_i)
      end
    end

    def extract_tax_id
      if (cnpj = @text[CNPJ_RE])
        [cnpj.gsub(/\D/, ""), "cnpj"]
      elsif (cpf = @text[CPF_RE])
        [cpf.gsub(/\D/, ""), "cpf"]
      else
        [nil, nil]
      end
    end

    # Heurística: primeira linha "de nome" — com letras, tamanho razoável, sem
    # ser valor/data/documento fiscal.
    def extract_counterparty_name
      lines.find do |l|
        l.length.between?(5, 60) &&
          l.match?(/[A-Za-zÀ-ÿ]{3,}/) &&
          !l.match?(MONEY_RE) && !l.match?(DATE_BR) &&
          !l.match?(CNPJ_RE) && !l.match?(CPF_RE) &&
          !l.match?(/\A\d/)
      end&.squeeze(" ")
    end

    def build_suggestion(fields)
      {
        "kind"                         => @default_kind,
        "description"                  => suggested_description(fields),
        "amount_cents"                 => fields[:amount_cents],
        "transacted_on"                => fields[:issued_on]&.iso8601,
        "counterparty_name_snapshot"   => fields[:counterparty_name],
        "counterparty_tax_id_snapshot" => normalized_tax_id(fields),
        "counterparty_tax_id_status"   => tax_id_status(fields)
      }.compact
    end

    def suggested_description(fields)
      base = fields[:counterparty_name].presence
      [base, "Documento digitalizado"].compact.uniq.join(" — ").presence || "Documento digitalizado"
    end

    # Confiança: completude dos campos ponderada pela qualidade do OCR.
    def score(fields)
      field_score  = 0
      field_score += 40 if fields[:amount_cents].present?
      field_score += 20 if fields[:issued_on].present?
      field_score += 20 if fields[:counterparty_name].present?
      field_score += 10 if valid_tax_id?(fields)

      factor = 0.5 + (0.5 * @ocr_confidence / 100.0)
      [(field_score * factor).round, 100].min
    end

    def tax_id_status(fields)
      return "not_informed" if fields[:tax_id].blank?
      valid_tax_id?(fields) ? "informed" : "invalid"
    end

    def valid_tax_id?(fields)
      raw = fields[:tax_id]
      return false if raw.blank?

      case fields[:tax_id_type]
      when "cnpj" then CNPJ.valid?(raw, strict: false)
      when "cpf"  then CPF.valid?(raw, strict: false)
      else false
      end
    end

    def normalized_tax_id(fields)
      return nil if fields[:tax_id].blank?

      case fields[:tax_id_type]
      when "cnpj" then CNPJ.new(fields[:tax_id]).formatted
      when "cpf"  then CPF.new(fields[:tax_id]).formatted
      else fields[:tax_id]
      end
    rescue StandardError
      fields[:tax_id]
    end

    def lines
      @lines ||= @text.split(/\r?\n/).map(&:strip).reject(&:blank?)
    end

    def money_to_cents(str)
      BigDecimal(str.gsub(".", "").gsub(",", ".")).mult(100, 10).to_i
    rescue ArgumentError, TypeError
      0
    end

    def safe_date(year, month, day)
      Date.new(year, month, day)
    rescue ArgumentError
      nil
    end

    def failure(message)
      Result.new(success: false, confidence: 0, fields: {},
                 suggested_transaction_data: {}, error: message)
    end
  end
end
