module Workspaces
  class ReceivablesController < Workspaces::BaseController
    before_action :set_receivable,   only: [:show, :edit, :update, :destroy, :settle]
    before_action :set_form_options, only: [:new, :create, :edit, :update]

    def index
      base = current_workspace.financial_transactions.receivables
                              .includes(:category, :counterparty)

      @filter = params[:filter].presence || "open"

      @receivables = case @filter
                     when "overdue"  then base.where("due_on < ?", Date.current).order(:due_on)
                     when "upcoming" then base.where(due_on: Date.current..7.days.from_now.to_date).order(:due_on)
                     when "received"
                       current_workspace.financial_transactions
                                        .where(kind: "income", settlement_status: "settled")
                                        .includes(:category, :counterparty)
                                        .order(settled_on: :desc)
                     when "cancelled"
                       current_workspace.financial_transactions
                                        .where(kind: "income", settlement_status: "cancelled")
                                        .includes(:category, :counterparty)
                                        .order(updated_at: :desc)
                     else
                       base.order(:due_on)
                     end

      @total_open_cents = current_workspace.financial_transactions.receivables.sum(:amount_cents)
      @overdue_count    = current_workspace.financial_transactions.receivables.overdue.count
      @upcoming_count   = current_workspace.financial_transactions.receivables.upcoming.count
    end

    def show; end

    def new
      @receivable = current_workspace.financial_transactions.new(
        kind:              "income",
        origin:            "manual",
        status:            "pending",
        settlement_status: "open",
        due_on:            Date.current
      )
    end

    def create
      @receivable = current_workspace.financial_transactions.new(receivable_params)
      @receivable.kind              = "income"
      @receivable.origin            = "manual"
      @receivable.status            = "pending"
      @receivable.settlement_status = "open"

      if @receivable.save
        redirect_to workspace_receivable_path(current_workspace, @receivable),
                    notice: "Conta a receber criada com sucesso."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @receivable.settlement_cancelled?
        redirect_to workspace_receivable_path(current_workspace, @receivable),
                    alert: "Conta cancelada não pode ser editada."
        return
      end

      if @receivable.update(receivable_params)
        redirect_to workspace_receivable_path(current_workspace, @receivable),
                    notice: "Conta a receber atualizada."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @receivable.settlement_settled?
        @receivable.update!(settlement_status: "cancelled", status: "cancelled")
        redirect_to workspace_receivables_path(current_workspace),
                    notice: "Conta já recebida foi cancelada (não pode ser excluída)."
      else
        @receivable.destroy!
        redirect_to workspace_receivables_path(current_workspace),
                    notice: "Conta a receber excluída."
      end
    end

    def settle
      if @receivable.settlement_open?
        @receivable.settle!
        redirect_to workspace_receivable_path(current_workspace, @receivable),
                    notice: "Conta marcada como recebida."
      else
        redirect_to workspace_receivable_path(current_workspace, @receivable),
                    alert: "Esta conta não está aberta."
      end
    end

    private

    def set_form_options
      @categories     = Category.where("workspace_id IS NULL OR workspace_id = ?", current_workspace.id)
                                .where(kind: "income").order(:name)
      @counterparties = current_workspace.counterparties.order(:name)
    end

    def set_receivable
      @receivable = current_workspace.financial_transactions
                                     .where(kind: "income")
                                     .where.not(settlement_status: nil)
                                     .find(params[:id])
    end

    def receivable_params
      params.require(:financial_transaction).permit(
        :description, :amount_brl, :due_on, :notes,
        :category_id, :counterparty_id, :document_id
      )
    end
  end
end
