# frozen_string_literal: true

module Aionis
  # Parser interno de documentos fiscais eletrônicos brasileiros (NF-e / NFC-e).
  #
  # É o passo 1 do pipeline descrito no CLAUDE.md: "XML fiscal: parser interno".
  # Puro Ruby (Nokogiri), sem OCR/IA. Extrai valor, data, emitente, CPF/CNPJ e
  # descrição, calcula um score de confiança e monta uma sugestão de lançamento.
  #
  # Segue a regra de produto: CPF/CNPJ é desejável mas NUNCA obrigatório — a
  # ausência dele jamais faz o parsing falhar.
  #
  # Uso:
  #   result = Aionis::FiscalXmlParser.new(xml_string).call
  #   result.success?                    # => true/false
  #   result.confidence                  # => 0..100
  #   result.fields                      # => Hash com dados brutos extraídos
  #   result.suggested_transaction_data  # => Hash pronto para pré-preencher lançamento
  class FiscalXmlParser
    PROCESSOR_NAME    = "fiscal_xml_parser"
    PROCESSOR_VERSION = "1.0"

    Result = Struct.new(
      :success, :confidence, :fields, :suggested_transaction_data, :error,
      keyword_init: true
    ) do
      def success? = success
    end

    def initialize(xml, default_kind: "expense")
      @xml          = xml.to_s
      @default_kind = default_kind
    end

    def self.call(xml, **opts) = new(xml, **opts).call

    def call
      doc = Nokogiri::XML(@xml)
      doc.remove_namespaces!

      inf = doc.at_xpath("//infNFe")
      return failure("XML não reconhecido como NF-e/NFC-e") if inf.nil?

      fields = extract_fields(inf)
      confidence = score(fields)

      Result.new(
        success:    fields[:amount_cents].present?,
        confidence: confidence,
        fields:     fields,
        suggested_transaction_data: build_suggestion(fields),
        error:      nil
      )
    rescue => e
      failure("Falha ao interpretar XML fiscal: #{e.message}")
    end

    private

    def extract_fields(inf)
      emit  = inf.at_xpath("emit")
      ide   = inf.at_xpath("ide")
      total = inf.at_xpath("total/ICMSTot")

      tax_id, tax_id_type = extract_tax_id(emit)

      {
        amount_cents:   parse_amount(text(total, "vNF")),
        issued_on:      parse_date(text(ide, "dhEmi") || text(ide, "dEmi")),
        counterparty_name: text(emit, "xNome") || text(emit, "xFant"),
        tax_id:         tax_id,
        tax_id_type:    tax_id_type,
        number:         text(ide, "nNF"),
        series:         text(ide, "serie"),
        nat_op:         text(ide, "natOp"),
        access_key:     inf["Id"].to_s.sub(/\ANFe/, "").presence,
        items:          extract_items(inf)
      }
    end

    def extract_items(inf)
      inf.xpath("det/prod/xProd").map { |n| n.text.strip }.reject(&:blank?).first(10)
    end

    def extract_tax_id(emit)
      return [nil, nil] if emit.nil?

      if (cnpj = text(emit, "CNPJ")).present?
        [cnpj, "cnpj"]
      elsif (cpf = text(emit, "CPF")).present?
        [cpf, "cpf"]
      else
        [nil, nil]
      end
    end

    def build_suggestion(fields)
      {
        "kind"                       => @default_kind,
        "description"                => suggested_description(fields),
        "amount_cents"               => fields[:amount_cents],
        "transacted_on"              => fields[:issued_on]&.iso8601,
        "counterparty_name_snapshot" => fields[:counterparty_name],
        "counterparty_tax_id_snapshot" => normalized_tax_id(fields),
        "counterparty_tax_id_status" => tax_id_status(fields)
      }.compact
    end

    def suggested_description(fields)
      base = fields[:counterparty_name].presence || fields[:nat_op].presence
      label =
        if fields[:number].present?
          "NF #{fields[:number]}"
        else
          "Documento fiscal"
        end
      first_item = fields[:items].first
      parts = [base, label, first_item].compact.uniq
      parts.join(" — ").presence || "Documento fiscal"
    end

    # Score de confiança conforme faixas do CLAUDE.md (0-60 baixa, 61-85 média,
    # 86-100 alta). Sem valor, a confiança fica baixa por natureza.
    def score(fields)
      s = 0
      s += 50 if fields[:amount_cents].present?
      s += 20 if fields[:issued_on].present?
      s += 20 if fields[:counterparty_name].present?
      s += 10 if valid_tax_id?(fields)
      [s, 100].min
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

    # Helpers de leitura

    def text(node, name)
      return nil if node.nil?
      child = node.at_xpath(name)
      child&.text&.strip.presence
    end

    def parse_amount(str)
      return nil if str.blank?
      BigDecimal(str).mult(100, 10).to_i
    rescue ArgumentError, TypeError
      nil
    end

    def parse_date(str)
      return nil if str.blank?
      # dhEmi vem como ISO8601 com timezone; dEmi vem como AAAA-MM-DD
      Date.parse(str)
    rescue ArgumentError, TypeError
      nil
    end

    def failure(message)
      Result.new(
        success: false, confidence: 0, fields: {},
        suggested_transaction_data: {}, error: message
      )
    end
  end
end
