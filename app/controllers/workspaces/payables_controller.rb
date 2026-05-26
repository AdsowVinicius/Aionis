module Workspaces
  class PayablesController < Workspaces::BaseController
    before_action :set_payable,      only: [:show, :edit, :update, :destroy, :settle]
    before_action :set_form_options, only: [:new, :create, :edit, :update]

    def index
      base = current_workspace.financial_transactions.payables
                              .includes(:category, :counterparty)

      @filter = params[:filter].presence || "open"

      @payables = case @filter
                  when "overdue"   then base.where("due_on < ?", Date.current).order(:due_on)
                  when "upcoming"  then base.where(due_on: Date.current..7.days.from_now.to_date).order(:due_on)
                  when "settled"
                    current_workspace.financial_transactions
                                     .where(kind: "expense", settlement_status: "settled")
                                     .includes(:category, :counterparty)
                                     .order(settled_on: :desc)
                  when "cancelled"
                    current_workspace.financial_transactions
                                     .where(kind: "expense", settlement_status: "cancelled")
                                     .includes(:category, :counterparty)
                                     .order(updated_at: :desc)
                  else
                    base.order(:due_on)
                  end

      @total_open_cents    = current_workspace.financial_transactions.payables.sum(:amount_cents)
      @overdue_count       = current_workspace.financial_transactions.payables.overdue.count
      @upcoming_count      = current_workspace.financial_transactions.payables.upcoming.count
    end

    def show; end

    def new
      @payable = current_workspace.financial_transactions.new(
        kind:               "expense",
        origin:             "manual",
        status:             "pending",
        settlement_status:  "open",
        due_on:             Date.current
      )
    end

    def create
      @payable = current_workspace.financial_transactions.new(payable_params)
      @payable.kind              = "expense"
      @payable.origin            = "manual"
      @payable.status            = "pending"
      @payable.settlement_status = "open"

      if @payable.save
        redirect_to workspace_payable_path(current_workspace, @payable),
                    notice: "Conta a pagar criada com sucesso."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @payable.settlement_cancelled?
        redirect_to workspace_payable_path(current_workspace, @payable),
                    alert: "Conta cancelada não pode ser editada."
        return
      end

      if @payable.update(payable_params)
        redirect_to workspace_payable_path(current_workspace, @payable),
                    notice: "Conta a pagar atualizada."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @payable.settlement_settled?
        @payable.update!(settlement_status: "cancelled", status: "cancelled")
        redirect_to workspace_payables_path(current_workspace),
                    notice: "Conta já liquidada foi cancelada (não pode ser excluída)."
      else
        @payable.destroy!
        redirect_to workspace_payables_path(current_workspace),
                    notice: "Conta a pagar excluída."
      end
    end

    def settle
      if @payable.settlement_open?
        @payable.settle!
        redirect_to workspace_payable_path(current_workspace, @payable),
                    notice: "Conta marcada como paga."
      else
        redirect_to workspace_payable_path(current_workspace, @payable),
                    alert: "Esta conta não está aberta."
      end
    end

    private

    def set_form_options
      @categories    = Category.where("workspace_id IS NULL OR workspace_id = ?", current_workspace.id)
                               .where(kind: "expense").order(:name)
      @counterparties = current_workspace.counterparties.order(:name)
    end

    def set_payable
      @payable = current_workspace.financial_transactions
                                  .where(kind: "expense")
                                  .where.not(settlement_status: nil)
                                  .find(params[:id])
    end

    def payable_params
      params.require(:financial_transaction).permit(
        :description, :amount_brl, :due_on, :notes,
        :category_id, :counterparty_id, :document_id
      )
    end
  end
end
