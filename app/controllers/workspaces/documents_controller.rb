module Workspaces
  class DocumentsController < Workspaces::BaseController
    before_action :set_document, only: [:show, :destroy, :trigger, :review, :confirm]

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

    # Tela de revisão da leitura automática (OCR/IA): mostra a confiança, os
    # campos extraídos e o texto bruto para o usuário confirmar ou corrigir.
    def review
      @extraction = @document.latest_extraction
      @builder    = Aionis::Documents::TransactionBuilder.new(@document)
      @transaction = @builder.build
    end

    # Confirma a leitura revisada e cria o lançamento a partir da extração.
    def confirm
      transaction = Aionis::Documents::TransactionBuilder.new(@document).build

      if transaction.nil?
        redirect_to review_workspace_document_path(current_workspace, @document),
                    alert: "Não há valor suficiente na leitura para criar um lançamento. Edite manualmente."
        return
      end

      transaction.status = "confirmed"
      if transaction.save
        AuditLog.log(
          action: "confirm", origin: "user",
          workspace: current_workspace, document: @document,
          financial_transaction: transaction,
          reason: "Leitura revisada e confirmada pelo usuário",
          confidence: @document.latest_extraction&.confidence_score
        )
        redirect_to workspace_financial_transaction_path(current_workspace, transaction),
                    notice: "Lançamento criado a partir da leitura do documento."
      else
        redirect_to review_workspace_document_path(current_workspace, @document),
                    alert: "Não foi possível criar o lançamento. Revise os dados."
      end
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
