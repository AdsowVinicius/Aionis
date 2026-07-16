module Workspaces
  # CRUD das regras de classificação (CategoryRule) por workspace.
  # Regras do sistema (origin "seed", workspace_id nulo) são somente leitura.
  # Regras "manual" e "learned" (aprendidas pelo RuleLearner) são editáveis.
  class CategoryRulesController < Workspaces::BaseController
    before_action :set_rule,             only: [:edit, :update, :destroy]
    before_action :require_editable_rule!, only: [:edit, :update, :destroy]

    def index
      base  = CategoryRule.for_workspace(current_workspace)
      scope = base.includes(:category, :counterparty)
      scope = scope.where(origin: params[:origin]) if CategoryRule::ORIGINS.include?(params[:origin])
      if params[:kind].present? && CategoryRule::KINDS.include?(params[:kind])
        scope = scope.where(kind: params[:kind])
      end

      # Globais primeiro em empate, depois maior prioridade e nome.
      @rules = scope.order(Arel.sql("workspace_id IS NULL DESC"), priority: :desc, name: :asc)

      @global_count  = base.where(workspace_id: nil).count
      @manual_count  = base.where(workspace_id: current_workspace.id, origin: "manual").count
      @learned_count = base.where(workspace_id: current_workspace.id, origin: "learned").count
    end

    def new
      @rule = CategoryRule.new(kind: "expense", confidence: 70, priority: 0, active: true)
      load_form_data
    end

    def create
      @rule = CategoryRule.new(rule_params)
      @rule.workspace = current_workspace
      @rule.origin    = "manual"

      if missing_condition?(@rule)
        add_condition_error
        load_form_data
        return render :new, status: :unprocessable_entity
      end

      if @rule.save
        redirect_to workspace_category_rules_path(current_workspace),
                    notice: "Regra criada com sucesso."
      else
        load_form_data
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      load_form_data
    end

    def update
      @rule.assign_attributes(rule_params)

      if missing_condition?(@rule)
        add_condition_error
        load_form_data
        return render :edit, status: :unprocessable_entity
      end

      if @rule.save
        redirect_to workspace_category_rules_path(current_workspace),
                    notice: "Regra atualizada com sucesso."
      else
        load_form_data
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @rule.destroy
      redirect_to workspace_category_rules_path(current_workspace),
                  notice: "Regra removida."
    end

    private

    def set_rule
      @rule = CategoryRule.find(params[:id])
      # Regra de outro workspace → 404
      if @rule.workspace_id.present? && @rule.workspace_id != current_workspace.id
        raise ActiveRecord::RecordNotFound
      end
    end

    # Regras do sistema (globais) não podem ser editadas/excluídas.
    def require_editable_rule!
      return unless @rule.global?

      redirect_to workspace_category_rules_path(current_workspace),
                  alert: "Regras do sistema não podem ser editadas ou excluídas."
    end

    # Uma regra sem nenhuma condição nunca casa (vide CategoryRule#matches?),
    # então exigimos ao menos uma no formulário — sem quebrar o backend.
    def missing_condition?(rule)
      rule.keywords.blank? && rule.tax_id.blank? && rule.counterparty_id.blank?
    end

    def add_condition_error
      @rule.errors.add(:base, "Informe ao menos uma condição: palavra-chave, CPF/CNPJ ou fornecedor.")
    end

    def load_form_data
      @categories     = Category.for_workspace(current_workspace).order(:name)
      @counterparties = current_workspace.counterparties.order(:name)
    end

    def rule_params
      params.require(:category_rule).permit(
        :name, :kind, :keywords, :category_id, :tax_id, :counterparty_id,
        :scope, :recurrence, :cost_type, :essentiality, :cost_center,
        :confidence, :priority, :active
      )
    end
  end
end
