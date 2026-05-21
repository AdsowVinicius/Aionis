module Workspaces
  class DashboardController < ApplicationController
    def show
      @workspace = current_workspace
      @recent_transactions = @workspace.financial_transactions
                                       .order(created_at: :desc)
                                       .limit(10)
    end
  end
end
