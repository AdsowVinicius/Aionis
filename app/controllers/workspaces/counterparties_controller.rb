module Workspaces
  class CounterpartiesController < Workspaces::BaseController
    before_action :set_counterparty, only: [:show, :edit, :update, :destroy]

    def index
      scope = current_workspace.counterparties
      scope = scope.where("name ILIKE ?", "%#{params[:q]}%") if params[:q].present?
      @counterparties = scope.includes(:financial_transactions, :documents).order(:name)

      base = current_workspace.counterparties
      @total_count         = base.count
      @with_tax_id_count   = base.where.not(tax_id: nil).count
      @without_tax_id_count = base.where(tax_id: nil).count
    end

    def new
      @counterparty = current_workspace.counterparties.new
    end

    def create
      @counterparty = current_workspace.counterparties.new(counterparty_params)
      set_tax_id_source

      if @counterparty.save
        redirect_to workspace_counterparty_path(current_workspace, @counterparty),
                    notice: "Fornecedor/cliente cadastrado com sucesso."
      else
        render :new, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordNotUnique
      @counterparty.errors.add(:tax_id, "já está cadastrado neste workspace")
      render :new, status: :unprocessable_entity
    end

    def show
      @transactions = @counterparty.financial_transactions.order(created_at: :desc).limit(5)
      @documents    = @counterparty.documents.with_attached_file.order(created_at: :desc).limit(5)
    end

    def edit; end

    def update
      @counterparty.assign_attributes(counterparty_params)
      set_tax_id_source

      if @counterparty.save
        redirect_to workspace_counterparty_path(current_workspace, @counterparty),
                    notice: "Fornecedor/cliente atualizado com sucesso."
      else
        render :edit, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordNotUnique
      @counterparty.errors.add(:tax_id, "já está cadastrado neste workspace")
      render :edit, status: :unprocessable_entity
    end

    def destroy
      @counterparty.destroy
      redirect_to workspace_counterparties_path(current_workspace),
                  notice: "Fornecedor/cliente removido. Lançamentos e documentos vinculados foram mantidos."
    end

    private

    def set_counterparty
      @counterparty = current_workspace.counterparties.find(params[:id])
    end

    def counterparty_params
      params.require(:counterparty).permit(:name, :kind, :tax_id, :notes)
    end

    def set_tax_id_source
      if @counterparty.tax_id.present?
        @counterparty.tax_id_source = "user_input"
      else
        @counterparty.tax_id_source = nil
      end
    end
  end
end
