module Workspaces
  class DashboardController < Workspaces::BaseController
    # Sem regra de negócio aqui: o DashboardPresenter compõe toda a inteligência
    # financeira (Aionis::Analytics::Dashboard) com os dados de página.
    def show
      @workspace      = current_workspace
      @dashboard      = DashboardPresenter.new(@workspace)
      @alerts_summary = @dashboard.alerts # usado pelo badge da sidebar
    end
  end
end
