# Landing page pública (página de vendas). Controller FINO: só carrega os
# números editáveis de config/aionis/landing.yml — nenhuma regra de negócio.
# Usuário logado nem chega aqui: a rota `authenticated :user` intercepta o root.
class LandingController < ApplicationController
  skip_before_action :authenticate_user!

  layout "landing"

  def index
    config = landing_config
    @founder_slots_total = config.fetch("founder_slots_total", 500).to_i
    # Vagas reais por padrão (total - workspaces criados); yml pode fixar.
    @founder_slots_left  = config["founder_slots_left"]&.to_i || computed_slots_left
    @price_now           = config.fetch("price_now", "")
    @price_after         = config.fetch("price_after", "")
    @pain_per_month      = config.fetch("pain_per_month", "")
    @show_testimonials   = config.fetch("show_testimonials", false)
  end

  private

  def landing_config
    YAML.load_file(Rails.root.join("config", "aionis", "landing.yml")) || {}
  rescue Errno::ENOENT
    {}
  end

  def computed_slots_left
    [@founder_slots_total - Workspace.count, 0].max
  end
end
