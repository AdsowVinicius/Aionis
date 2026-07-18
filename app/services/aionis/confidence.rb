# frozen_string_literal: true

module Aionis
  # Faixas de confiança da classificação/extração — fonte única de verdade para
  # os limiares descritos no CLAUDE.md §4. Antes esses números (86/61/60)
  # estavam duplicados em vários services/jobs/controllers.
  #
  #   0–60   baixa  → pedir correção/nova imagem (nunca lançar sozinho)
  #   61–85  média  → sugerir e pedir confirmação
  #   86–100 alta   → lançar e apenas avisar
  module Confidence
    HIGH_MIN   = 86           # a partir daqui: alta confiança (auto)
    MEDIUM_MIN = 61           # a partir daqui: média confiança (sugere/confirma)
    LOW_MAX    = MEDIUM_MIN - 1 # 60 — teto da faixa de baixa confiança

    module_function

    def high?(score)   = score.to_i >= HIGH_MIN
    def medium?(score) = score.to_i.between?(MEDIUM_MIN, HIGH_MIN - 1)
    def low?(score)    = score.to_i <= LOW_MAX

    # Confiável o bastante para pré-preencher/sugerir (média ou alta).
    def actionable?(score) = score.to_i >= MEDIUM_MIN

    def band(score)
      return :high   if high?(score)
      return :medium if medium?(score)

      :low
    end
  end
end
