# frozen_string_literal: true

module Aionis
  module Agent
    # Converte período em linguagem natural ("esse mês", "últimos 30 dias",
    # "janeiro") num Range de datas, SEMPRE no backend — a LLM nunca manda
    # datas cruas sem validação. Entrada desconhecida devolve nil (a tool
    # responde pedindo esclarecimento em vez de chutar).
    class PeriodParser
      MONTHS = {
        "janeiro" => 1, "fevereiro" => 2, "marco" => 3, "março" => 3,
        "abril" => 4, "maio" => 5, "junho" => 6, "julho" => 7,
        "agosto" => 8, "setembro" => 9, "outubro" => 10,
        "novembro" => 11, "dezembro" => 12
      }.freeze

      def self.call(text, today: Date.current) = new(today).call(text)

      def initialize(today = Date.current)
        @today = today
      end

      # @return [Range<Date>, nil]
      def call(text)
        normalized = normalize(text)
        return month_range(@today) if normalized.blank? # default: mês atual

        fixed_period(normalized) || last_days(normalized) || named_month(normalized)
      end

      private

      def normalize(text)
        text.to_s.unicode_normalize(:nfkd).gsub(/\p{Mn}/, "").downcase.strip
      end

      def fixed_period(text)
        case text
        when "hoje"                                   then @today..@today
        when "ontem"                                  then (@today - 1)..(@today - 1)
        when /\A(essa|esta) semana\z/                 then @today.beginning_of_week..@today.end_of_week
        when /\A(esse|este) mes\z/, "mes atual"       then month_range(@today)
        when /\Ames passado\z/, "ultimo mes"          then month_range(@today.prev_month)
        when /\A(esse|este) ano\z/, "ano atual"       then @today.beginning_of_year..@today.end_of_year
        when "ano passado"                            then (@today - 1.year).beginning_of_year..(@today - 1.year).end_of_year
        end
      end

      def last_days(text)
        match = text.match(/\Aultimos?\s+(\d{1,3})\s+dias?\z/)
        return nil unless match

        days = match[1].to_i.clamp(1, 366)
        (@today - (days - 1))..@today
      end

      # "janeiro", "janeiro de 2026", "janeiro/2026", "01/2026", "2026-01"
      def named_month(text)
        if (m = text.match(/\A(#{MONTHS.keys.join('|')})(?:\s+de\s+(\d{4})|\/(\d{4}))?\z/))
          year  = (m[2] || m[3] || @today.year).to_i
          month = MONTHS[m[1]]
          # Mês sem ano: assume o mais recente já ocorrido (janeiro em julho = este ano).
          year -= 1 if m[2].nil? && m[3].nil? && Date.new(year, month, 1) > @today
          return month_range(Date.new(year, month, 1))
        end

        if (m = text.match(%r{\A(\d{1,2})/(\d{4})\z})) && m[1].to_i.between?(1, 12)
          return month_range(Date.new(m[2].to_i, m[1].to_i, 1))
        end

        if (m = text.match(/\A(\d{4})-(\d{1,2})\z/)) && m[2].to_i.between?(1, 12)
          return month_range(Date.new(m[1].to_i, m[2].to_i, 1))
        end

        nil
      end

      def month_range(date) = date.beginning_of_month..date.end_of_month
    end
  end
end
