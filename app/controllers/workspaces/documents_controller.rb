module Workspaces
  class DocumentsController < Workspaces::BaseController
    def index
      @documents = current_workspace.documents.order(created_at: :desc)
    end
  end
end
