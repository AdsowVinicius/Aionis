module Workspaces
  class FinancialTransactionsController < Workspaces::BaseController
    before_action :set_transaction, only: [:show, :edit, :update, :destroy]

    def index
      @transactions = current_workspace.financial_transactions
                                       .includes(:category, :counterparty)

      if params[:kind].present? && FinancialTransaction.kinds.key?(params[:kind])
        @transactions = @transactions.where(kind: params[:kind])
      end

      if params[:status].present? && FinancialTransaction.statuses.key?(params[:status])
        @transactions = @transactions.where(status: params[:status])
      end

      if params[:category_id].present?
        @transactions = @transactions.where(category_id: params[:category_id])
      end

      if params[:q].present?
        @transactions = @transactions.where("description ILIKE ?", "%#{params[:q]}%")
      end

      if params[:period].present?
        year, month = params[:period].split("-").map(&:to_i)
        if year.to_i > 0 && month.to_i.between?(1, 12)
          range = Date.new(year, month, 1)..Date.new(year, month, 1).end_of_month
          @transactions = @transactions.where(transacted_on: range)
        end
      end

      @transactions = @transactions.order(transacted_on: :desc, created_at: :desc)

      # Resumo sempre sobre todos os lançamentos do workspace (sem filtros)
      base = current_workspace.financial_transactions
      @summary_income_cents  = base.where(kind: "income").sum(:amount_cents)
      @summary_expense_cents = base.where(kind: "expense").sum(:amount_cents)
      @summary_balance_cents = @summary_income_cents - @summary_expense_cents
      @summary_count         = base.count

      @categories = Category.for_workspace(current_workspace).order(:name)
    end

    def show; end

    def new
      @transaction = current_workspace.financial_transactions.new(
        transacted_on: Date.current,
        status: "pending"
      )
      load_form_data
    end

    def create
      @transaction = current_workspace.financial_transactions.new(transaction_params)
      @transaction.origin = "manual"
      if @transaction.save
        redirect_to workspace_financial_transactions_path(current_workspace),
                    notice: "Lançamento criado com sucesso."
      else
        load_form_data
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      load_form_data
    end

    def update
      # origin não pode ser alterado pelo usuário
      if @transaction.update(transaction_params)
        redirect_to workspace_financial_transaction_path(current_workspace, @transaction),
                    notice: "Lançamento atualizado."
      else
        load_form_data
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

    def load_form_data
      @categories     = Category.for_workspace(current_workspace).order(:name)
      @counterparties = current_workspace.counterparties.order(:name)
    end

    def transaction_params
      params.require(:financial_transaction).permit(
        :kind, :description, :amount_brl, :transacted_on, :status,
        :category_id, :counterparty_id
        # document_id, counterparty_id e category_id são opcionais
        # origin NÃO está aqui — é sempre forçado como "manual"
      )
    end
  end
end
