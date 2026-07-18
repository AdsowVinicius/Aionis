module Workspaces
  # Contas a Receber = FinancialTransactions de receita com settlement_status.
  # Toda a lógica CRUD/filtros vive em Workspaces::SettlementAccounts.
  class ReceivablesController < Workspaces::BaseController
    include Workspaces::SettlementAccounts

    MESSAGES = {
      created:           "Conta a receber criada com sucesso.",
      updated:           "Conta a receber atualizada.",
      destroyed:         "Conta a receber excluída.",
      settled:           "Conta marcada como recebida.",
      settled_cancelled: "Conta já recebida foi cancelada (não pode ser excluída)."
    }.freeze

    private

    def collection_scope    = :receivables
    def transaction_kind    = "income"
    def settled_filter_name = "received"

    def record_path(record) = workspace_receivable_path(current_workspace, record)
    def collection_path     = workspace_receivables_path(current_workspace)
  end
end
