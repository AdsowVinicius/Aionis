module Workspaces
  class CategoriesController < Workspaces::BaseController
    before_action :set_category,              only: [:show, :edit, :update, :destroy]
    before_action :require_workspace_category!, only: [:edit, :update, :destroy]

    def index
      scope = Category.for_workspace(current_workspace)
      scope = scope.where("name ILIKE ?", "%#{params[:q]}%") if params[:q].present?
      scope = scope.where(kind: params[:kind])              if params[:kind].present?
      @categories = scope.includes(:financial_transactions, :parent, :subcategories)
                         .order(:name)

      @total_count  = Category.for_workspace(current_workspace).count
      @global_count = Category.global.count
      @custom_count = current_workspace.categories.count
    end

    def new
      @category       = current_workspace.categories.new
      @parent_options = parent_options
    end

    def create
      @category = current_workspace.categories.new(category_params)

      if @category.save
        redirect_to workspace_category_path(current_workspace, @category),
                    notice: "Categoria criada com sucesso."
      else
        @parent_options = parent_options
        render :new, status: :unprocessable_entity
      end
    end

    def show
      @transactions = @category.financial_transactions.order(created_at: :desc).limit(5)
    end

    def edit
      @parent_options = parent_options
    end

    def update
      if @category.update(category_params)
        redirect_to workspace_category_path(current_workspace, @category),
                    notice: "Categoria atualizada com sucesso."
      else
        @parent_options = parent_options
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @category.destroy
      redirect_to workspace_categories_path(current_workspace),
                  notice: "Categoria removida. Lançamentos vinculados foram mantidos."
    end

    private

    def set_category
      @category = Category.find(params[:id])
      # Categoria de outro workspace → 404
      if @category.workspace_id.present? && @category.workspace_id != current_workspace.id
        raise ActiveRecord::RecordNotFound
      end
    end

    def require_workspace_category!
      return unless @category.workspace_id.nil?

      redirect_to workspace_category_path(current_workspace, @category),
                  alert: "Categorias do sistema não podem ser editadas ou excluídas."
    end

    def category_params
      params.require(:category).permit(:name, :kind, :parent_id, :cost_type, :essentiality)
    end

    def parent_options
      scope = Category.for_workspace(current_workspace).order(:name)
      scope = scope.where.not(id: @category.id) if @category&.persisted?
      scope
    end
  end
end
