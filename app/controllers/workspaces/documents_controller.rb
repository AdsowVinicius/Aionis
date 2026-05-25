module Workspaces
  class DocumentsController < Workspaces::BaseController
    before_action :set_document, only: [:show, :destroy, :trigger]

    def index
      @documents = current_workspace.documents
                                    .with_attached_file
                                    .includes(:document_extractions)
                                    .order(created_at: :desc)

      base = current_workspace.documents
      @total_count     = base.count
      @pending_count   = base.where(status: "pending").count
      @processed_count = base.where(status: "processed").count
      @failed_count    = base.where(status: "failed").count
    end

    def show
      @extractions    = @document.document_extractions.order(created_at: :desc)
      @transactions   = @document.financial_transactions.order(created_at: :desc).limit(10)
    end

    def trigger
      ProcessDocumentJob.perform_later(@document.id)
      redirect_to workspace_document_path(current_workspace, @document),
                  notice: "Documento enviado para processamento."
    end

    def new
      @document = current_workspace.documents.new
    end

    def create
      @document = current_workspace.documents.new(document_params)
      @document.source = "web"
      @document.status = "pending"

      if @document.save
        redirect_to workspace_document_path(current_workspace, @document),
                    notice: "Documento enviado com sucesso."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      @document.file.purge if @document.file.attached?
      @document.destroy
      redirect_to workspace_documents_path(current_workspace),
                  notice: "Documento removido."
    end

    private

    def set_document
      @document = current_workspace.documents.find(params[:id])
    end

    def document_params
      params.require(:document).permit(:file, :notes)
    end
  end
end
