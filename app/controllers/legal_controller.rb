# Páginas legais públicas (Política de Privacidade, futuramente Termos de Uso).
# Controller FINO: só carrega os dados da empresa de config/aionis/legal.yml —
# nenhuma regra de negócio. Precisa ser público e sem autenticação: a Meta
# valida a URL da política antes de aprovar o app do WhatsApp, e o titular dos
# dados tem que conseguir ler sem ter conta (LGPD art. 9º).
class LegalController < ApplicationController
  skip_before_action :authenticate_user!

  layout "landing"

  def privacy
    @legal = legal_config
  end

  private

  def legal_config
    YAML.load_file(Rails.root.join("config", "aionis", "legal.yml")) || {}
  rescue Errno::ENOENT
    {}
  end
end
