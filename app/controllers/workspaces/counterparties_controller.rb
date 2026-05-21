module Workspaces
  class CounterpartiesController < Workspaces::BaseController
    def index
      @counterparties = current_workspace.counterparties.order(:name)
    end
  end
end
