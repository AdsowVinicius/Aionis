module Workspaces
  # Tela de conciliação bancária (Open Finance): revisar as sugestões de match
  # entre transações bancárias e lançamentos. Controller fino — a regra vive em
  # Aionis::OpenFinance::ReconciliationReview.
  class ReconciliationsController < Workspaces::BaseController
    before_action :set_match, only: [:confirm, :reject]

    STATUSES = %w[suggested confirmed rejected].freeze

    def index
      @status  = STATUSES.include?(params[:status]) ? params[:status] : "suggested"
      @matches = current_workspace.reconciliation_matches.where(status: @status)
                                  .includes(:bank_transaction, financial_transaction: :category)
                                  .order(score: :desc, created_at: :desc)
      @counts  = current_workspace.reconciliation_matches.group(:status).count
    end

    def confirm
      Aionis::OpenFinance::ReconciliationReview.confirm(@match)
      redirect_to workspace_reconciliations_path(current_workspace), notice: "Conciliação confirmada."
    end

    def reject
      Aionis::OpenFinance::ReconciliationReview.reject(@match)
      redirect_to workspace_reconciliations_path(current_workspace), notice: "Sugestão rejeitada."
    end

    private

    def set_match
      @match = current_workspace.reconciliation_matches.find(params[:id])
    end
  end
end
