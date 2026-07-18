module Workspaces
  # Contas a Pagar = FinancialTransactions de despesa com settlement_status.
  # Toda a lógica CRUD/filtros vive em Workspaces::SettlementAccounts.
  class PayablesController < Workspaces::BaseController
    include Workspaces::SettlementAccounts

    MESSAGES = {
      created:           "Conta a pagar criada com sucesso.",
      updated:           "Conta a pagar atualizada.",
      destroyed:         "Conta a pagar excluída.",
      settled:           "Conta marcada como paga.",
      settled_cancelled: "Conta já liquidada foi cancelada (não pode ser excluída)."
    }.freeze

    private

    def collection_scope    = :payables
    def transaction_kind    = "expense"
    def settled_filter_name = "settled"

    def record_path(record) = workspace_payable_path(current_workspace, record)
    def collection_path     = workspace_payables_path(current_workspace)
  end
end
