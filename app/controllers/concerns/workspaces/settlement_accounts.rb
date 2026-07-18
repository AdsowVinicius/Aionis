module Workspaces
  # Comportamento compartilhado entre Contas a Pagar (despesas) e Contas a
  # Receber (receitas). Ambas são FinancialTransactions com settlement_status;
  # as diferenças (kind, textos, rotas) vêm dos métodos de configuração que cada
  # controller que inclui este concern implementa:
  #
  #   collection_scope    -> :payables / :receivables (scope do model)
  #   transaction_kind    -> "expense" / "income"
  #   settled_filter_name -> "settled"  / "received"  (nome da aba/filtro)
  #   record_path(record) / collection_path -> route helpers do recurso
  #   MESSAGES            -> textos de flash (constante do controller)
  module SettlementAccounts
    extend ActiveSupport::Concern

    included do
      before_action :set_record,       only: %i[show edit update destroy settle]
      before_action :set_form_options, only: %i[new create edit update]
    end

    def index
      open_scope = current_workspace.financial_transactions.public_send(collection_scope)
      @filter    = params[:filter].presence || "open"
      @records   = filtered_collection(open_scope.includes(:category, :counterparty), @filter)

      @total_open_cents = open_scope.sum(:amount_cents)
      @overdue_count    = open_scope.overdue.count
      @upcoming_count   = open_scope.upcoming.count
    end

    def show; end

    def new
      @record = current_workspace.financial_transactions.new(
        kind:              transaction_kind,
        origin:            "manual",
        status:            "pending",
        settlement_status: "open",
        due_on:            Date.current
      )
    end

    def create
      @record = current_workspace.financial_transactions.new(record_params)
      @record.assign_attributes(
        kind: transaction_kind, origin: "manual",
        status: "pending", settlement_status: "open"
      )

      if @record.save
        redirect_to record_path(@record), notice: message(:created)
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @record.settlement_cancelled?
        redirect_to record_path(@record), alert: "Conta cancelada não pode ser editada."
        return
      end

      if @record.update(record_params)
        redirect_to record_path(@record), notice: message(:updated)
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @record.settlement_settled?
        # Conta já liquidada não pode ser excluída — apenas cancelada.
        @record.update!(settlement_status: "cancelled", status: "cancelled")
        redirect_to collection_path, notice: message(:settled_cancelled)
      else
        @record.destroy!
        redirect_to collection_path, notice: message(:destroyed)
      end
    end

    def settle
      if @record.settlement_open?
        @record.settle!
        redirect_to record_path(@record), notice: message(:settled)
      else
        redirect_to record_path(@record), alert: "Esta conta não está aberta."
      end
    end

    private

    def filtered_collection(open_scope, filter)
      case filter
      when "overdue"
        open_scope.where("due_on < ?", Date.current).order(:due_on)
      when "upcoming"
        open_scope.where(due_on: Date.current..7.days.from_now.to_date).order(:due_on)
      when settled_filter_name
        settlement_collection("settled").order(settled_on: :desc)
      when "cancelled"
        settlement_collection("cancelled").order(updated_at: :desc)
      else
        open_scope.order(:due_on)
      end
    end

    def settlement_collection(settlement_status)
      current_workspace.financial_transactions
                       .where(kind: transaction_kind, settlement_status: settlement_status)
                       .includes(:category, :counterparty)
    end

    def set_record
      @record = current_workspace.financial_transactions
                                 .where(kind: transaction_kind)
                                 .where.not(settlement_status: nil)
                                 .find(params[:id])
    end

    def set_form_options
      @categories     = Category.where("workspace_id IS NULL OR workspace_id = ?", current_workspace.id)
                                .where(kind: transaction_kind).order(:name)
      @counterparties = current_workspace.counterparties.order(:name)
      @documents      = current_workspace.documents.with_attached_file.order(created_at: :desc)
    end

    def record_params
      params.require(:financial_transaction).permit(
        :description, :amount_brl, :due_on, :notes,
        :category_id, :counterparty_id, :document_id
      )
    end

    def message(key) = self.class::MESSAGES.fetch(key)
  end
end
