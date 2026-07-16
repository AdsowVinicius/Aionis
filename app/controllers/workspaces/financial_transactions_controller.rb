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
      prefill_from_params
      suggest_classification
      load_form_data
    end

    def create
      @transaction = current_workspace.financial_transactions.new(transaction_params)
      @transaction.origin = "manual"
      classify(@transaction)
      if @transaction.save
        learn_from_correction(@transaction)
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
      @transaction.assign_attributes(transaction_params)
      classify(@transaction)
      if @transaction.save
        learn_from_correction(@transaction)
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

    def prefill_from_params
      if params[:document_id].present?
        doc = current_workspace.documents.find_by(id: params[:document_id])
        raise ActiveRecord::RecordNotFound unless doc
        @transaction.document = doc
        prefill_from_extraction(doc)
      end

      if params[:counterparty_id].present?
        cp = current_workspace.counterparties.find_by(id: params[:counterparty_id])
        raise ActiveRecord::RecordNotFound unless cp
        @transaction.counterparty = cp
      end

      if params[:category_id].present?
        cat = Category.for_workspace(current_workspace).find_by(id: params[:category_id])
        raise ActiveRecord::RecordNotFound unless cat
        @transaction.category = cat
      end
    end

    # Pré-preenche o lançamento a partir da última extração do documento
    # (parser fiscal de XML). Só preenche campos que o usuário ainda não passou
    # explicitamente e que a extração ofereceu. CPF/CNPJ permanece opcional.
    def prefill_from_extraction(doc)
      extraction = doc.latest_extraction
      suggestion = extraction&.suggested_transaction_data
      return if suggestion.blank?

      @suggested_from_extraction = true
      @suggested_confidence      = extraction.confidence_score

      @transaction.kind          = suggestion["kind"] if suggestion["kind"].present?
      @transaction.description   = suggestion["description"] if suggestion["description"].present?

      if suggestion["amount_cents"].present?
        @transaction.amount_cents = suggestion["amount_cents"].to_i
      end

      if suggestion["transacted_on"].present?
        @transaction.transacted_on = Date.parse(suggestion["transacted_on"]) rescue nil
      end

      @transaction.counterparty_name_snapshot   = suggestion["counterparty_name_snapshot"]
      @transaction.counterparty_tax_id_snapshot = suggestion["counterparty_tax_id_snapshot"]
      @transaction.counterparty_tax_id_status   = suggestion["counterparty_tax_id_status"]

      # Se houver CPF/CNPJ válido, tenta vincular a um fornecedor já existente
      link_existing_counterparty(doc, suggestion["counterparty_tax_id_snapshot"])
    end

    def link_existing_counterparty(doc, tax_id_formatted)
      return if @transaction.counterparty_id.present?

      digits = tax_id_formatted.to_s.gsub(/\D/, "")
      if digits.present?
        cp = current_workspace.counterparties.find do |c|
          c.tax_id.to_s.gsub(/\D/, "") == digits
        end
        @transaction.counterparty = cp if cp
      end

      # Fallback: fornecedor já associado ao documento
      @transaction.counterparty ||= doc.counterparty
    end

    def load_form_data
      @categories     = Category.for_workspace(current_workspace).order(:name)
      @counterparties = current_workspace.counterparties.order(:name)
      @documents      = current_workspace.documents.with_attached_file.order(created_at: :desc)
    end

    # Sugestão do motor de classificação para exibir no formulário de novo
    # lançamento. Só roda quando há descrição e categoria ainda em branco.
    # Pré-preenche os campos (apenas os vazios) quando a confiança é média+ (>=61).
    def suggest_classification
      return if @transaction.description.blank? || @transaction.category_id.present?

      @classification_suggestion = Aionis::ClassificationEngine.for_transaction(@transaction).call
      if @classification_suggestion.confidence >= 61
        @transaction.apply_classification(@classification_suggestion, only_blank: true)
      end
    end

    # Classifica o lançamento antes de salvar. Categoria escolhida pelo usuário
    # é tratada como correção manual (alta confiança e vira histórico); caso
    # contrário aplica a sugestão do motor. Nunca bloqueia — categoria é opcional.
    def classify(transaction)
      suggestion = Aionis::ClassificationEngine.for_transaction(transaction).call

      if transaction.category_id.present?
        category = Category.for_workspace(current_workspace).find_by(id: transaction.category_id)
        transaction.cost_type    ||= category&.cost_type
        transaction.essentiality ||= category&.essentiality
        transaction.scope        ||= suggestion.scope
        transaction.recurrence   ||= suggestion.recurrence
        transaction.cost_center  ||= suggestion.cost_center
        transaction.classification_confidence = 100
        transaction.classification_source     = "manual"
        transaction.classification_reasons    = ["Categoria definida manualmente pelo usuário"]
      else
        transaction.apply_classification(suggestion, only_blank: true)
      end
    end

    # Aprende (ou reforça) uma regra de classificação a partir da correção
    # manual do usuário. Best-effort: nunca deve interromper o fluxo — se algo
    # falhar, apenas registra e segue.
    def learn_from_correction(transaction)
      Aionis::RuleLearner.for(transaction).call
    rescue => e
      Rails.logger.warn("[RuleLearner] não aprendeu regra: #{e.class}: #{e.message}")
    end

    def transaction_params
      params.require(:financial_transaction).permit(
        :kind, :description, :amount_brl, :transacted_on, :status,
        :category_id, :counterparty_id, :document_id,
        :cost_type, :essentiality, :scope, :recurrence, :cost_center,
        :counterparty_name_snapshot, :counterparty_tax_id_snapshot, :counterparty_tax_id_status
      )
    end
  end
end
