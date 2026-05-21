module Workspaces
  class CategoriesController < Workspaces::BaseController
    def index
      @categories = Category.for_workspace(current_workspace).order(:name)
    end
  end
end
