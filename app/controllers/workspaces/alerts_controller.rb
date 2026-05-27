module Workspaces
  class AlertsController < Workspaces::BaseController
    def index
      @alerts = Workspaces::AlertsSummary.new(current_workspace)
    end
  end
end
