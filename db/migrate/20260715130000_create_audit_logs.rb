class CreateAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_logs do |t|
      # Contexto (todos opcionais — eventos de sistema/job podem não ter usuário)
      t.bigint :workspace_id
      t.bigint :user_id
      t.bigint :document_id
      # NÃO usar "transaction" (colidiria com ActiveRecord.transaction)
      t.bigint :financial_transaction_id

      # Entidade auditada (polimórfica) — qualquer model do domínio
      t.string :auditable_type
      t.bigint :auditable_id

      # O que aconteceu
      t.string  :action,  null: false
      t.string  :origin,  null: false
      t.text    :reason
      t.string  :provider
      t.integer :confidence
      t.string  :summary

      # Antes/depois e metadados livres
      t.jsonb :before_data, null: false, default: {}
      t.jsonb :after_data,  null: false, default: {}
      t.jsonb :metadata,    null: false, default: {}

      # Registro imutável: apenas created_at (sem updated_at)
      t.datetime :created_at, null: false
    end

    # Índices para consultas eficientes
    add_index :audit_logs, [:workspace_id, :created_at]
    add_index :audit_logs, [:workspace_id, :action]
    add_index :audit_logs, [:workspace_id, :origin]
    add_index :audit_logs, [:auditable_type, :auditable_id]
    add_index :audit_logs, :financial_transaction_id
    add_index :audit_logs, :document_id
    add_index :audit_logs, :user_id
  end
end
