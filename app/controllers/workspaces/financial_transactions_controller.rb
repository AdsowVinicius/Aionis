module Workspaces
  class FinancialTransactionsController < Workspaces::BaseController
    before_action :set_transaction, only: [:show, :edit, :update, :destroy]

    def index
      @transactions = current_workspace.financial_transactions
                                       .includes(:category, :counterparty)
                                       .order(transacted_on: :desc, created_at: :desc)
    end

    def show; end

    def new
      @transaction = current_workspace.financial_transactions.new
    end

    def create
      @transaction = current_workspace.financial_transactions.new(transaction_params)
      if @transaction.save
        redirect_to workspace_financial_transactions_path(current_workspace),
                    notice: "Lançamento criado com sucesso."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @transaction.update(transaction_params)
        redirect_to workspace_financial_transaction_path(current_workspace, @transaction),
                    notice: "Lançamento atualizado."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @transaction.destroy
      redirect_to workspace_financial_transactions_path(current_workspace),
                  notice: "Lançamento removido."
    end

    private

    def set_transaction
      @transaction = current_workspace.financial_transactions.find(params[:id])
    end

    def transaction_params
      params.require(:financial_transaction).permit(
        :kind, :description, :amount_cents, :transacted_on, :origin,
        :category_id, :counterparty_id, :document_id,
        :counterparty_name_snapshot, :counterparty_tax_id_snapshot
      )
    end
  end
end
