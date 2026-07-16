# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_07_15_130000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "audit_logs", force: :cascade do |t|
    t.string "action", null: false
    t.jsonb "after_data", default: {}, null: false
    t.bigint "auditable_id"
    t.string "auditable_type"
    t.jsonb "before_data", default: {}, null: false
    t.integer "confidence"
    t.datetime "created_at", null: false
    t.bigint "document_id"
    t.bigint "financial_transaction_id"
    t.jsonb "metadata", default: {}, null: false
    t.string "origin", null: false
    t.string "provider"
    t.text "reason"
    t.string "summary"
    t.bigint "user_id"
    t.bigint "workspace_id"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_logs_on_auditable_type_and_auditable_id"
    t.index ["document_id"], name: "index_audit_logs_on_document_id"
    t.index ["financial_transaction_id"], name: "index_audit_logs_on_financial_transaction_id"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
    t.index ["workspace_id", "action"], name: "index_audit_logs_on_workspace_id_and_action"
    t.index ["workspace_id", "created_at"], name: "index_audit_logs_on_workspace_id_and_created_at"
    t.index ["workspace_id", "origin"], name: "index_audit_logs_on_workspace_id_and_origin"
  end

  create_table "categories", force: :cascade do |t|
    t.string "cost_type"
    t.datetime "created_at", null: false
    t.string "essentiality"
    t.boolean "is_system_default", default: false, null: false
    t.string "kind", null: false
    t.string "name", null: false
    t.integer "parent_id"
    t.datetime "updated_at", null: false
    t.bigint "workspace_id"
    t.index ["parent_id"], name: "index_categories_on_parent_id"
    t.index ["workspace_id", "name"], name: "index_categories_on_workspace_id_and_name"
    t.index ["workspace_id"], name: "index_categories_on_workspace_id"
  end

  create_table "category_rules", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.integer "category_id"
    t.integer "confidence", default: 70, null: false
    t.string "cost_center"
    t.string "cost_type"
    t.integer "counterparty_id"
    t.datetime "created_at", null: false
    t.string "essentiality"
    t.string "keywords"
    t.string "kind"
    t.string "name", null: false
    t.string "origin", default: "manual", null: false
    t.integer "priority", default: 0, null: false
    t.string "recurrence"
    t.string "scope"
    t.string "tax_id"
    t.integer "times_reinforced", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_id"
    t.index ["counterparty_id"], name: "index_category_rules_on_counterparty_id"
    t.index ["priority"], name: "index_category_rules_on_priority"
    t.index ["tax_id"], name: "index_category_rules_on_tax_id"
    t.index ["workspace_id", "active"], name: "index_category_rules_on_workspace_id_and_active"
    t.index ["workspace_id", "origin"], name: "index_category_rules_on_workspace_id_and_origin"
    t.index ["workspace_id"], name: "index_category_rules_on_workspace_id"
  end

  create_table "counterparties", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.string "name", null: false
    t.text "notes"
    t.string "tax_id"
    t.string "tax_id_source"
    t.string "tax_id_status", default: "not_informed", null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["workspace_id", "name"], name: "index_counterparties_on_workspace_id_and_name"
    t.index ["workspace_id", "tax_id"], name: "index_counterparties_on_workspace_and_tax_id", unique: true, where: "(tax_id IS NOT NULL)"
    t.index ["workspace_id"], name: "index_counterparties_on_workspace_id"
  end

  create_table "document_extractions", force: :cascade do |t|
    t.integer "confidence_score"
    t.datetime "created_at", null: false
    t.bigint "document_id", null: false
    t.text "error_message"
    t.jsonb "extracted_data", default: {}, null: false
    t.datetime "finished_at"
    t.string "processor_name"
    t.string "processor_version"
    t.text "raw_text"
    t.datetime "started_at"
    t.string "status", default: "pending", null: false
    t.jsonb "suggested_transaction_data", default: {}, null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["document_id"], name: "index_document_extractions_on_document_id"
    t.index ["status"], name: "index_document_extractions_on_status"
    t.index ["workspace_id", "document_id"], name: "index_document_extractions_on_workspace_id_and_document_id"
    t.index ["workspace_id"], name: "index_document_extractions_on_workspace_id"
  end

  create_table "documents", force: :cascade do |t|
    t.integer "counterparty_id"
    t.datetime "created_at", null: false
    t.text "notes"
    t.string "source", default: "web", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["counterparty_id"], name: "index_documents_on_counterparty_id"
    t.index ["workspace_id", "status"], name: "index_documents_on_workspace_id_and_status"
    t.index ["workspace_id"], name: "index_documents_on_workspace_id"
  end

  create_table "financial_transactions", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.integer "category_id"
    t.integer "classification_confidence"
    t.jsonb "classification_reasons", default: [], null: false
    t.string "classification_source"
    t.string "cost_center"
    t.string "cost_type"
    t.integer "counterparty_id"
    t.string "counterparty_name_snapshot"
    t.string "counterparty_tax_id_snapshot"
    t.string "counterparty_tax_id_status"
    t.datetime "created_at", null: false
    t.string "description", null: false
    t.integer "document_id"
    t.date "due_on"
    t.string "essentiality"
    t.string "kind", null: false
    t.text "notes"
    t.string "origin", default: "manual", null: false
    t.string "recurrence"
    t.string "scope"
    t.date "settled_on"
    t.string "settlement_status"
    t.string "status", default: "pending", null: false
    t.date "transacted_on"
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["category_id"], name: "index_financial_transactions_on_category_id"
    t.index ["counterparty_id"], name: "index_financial_transactions_on_counterparty_id"
    t.index ["document_id"], name: "index_financial_transactions_on_document_id"
    t.index ["workspace_id", "settlement_status", "due_on"], name: "index_financial_transactions_on_settlement"
    t.index ["workspace_id", "status"], name: "index_financial_transactions_on_workspace_id_and_status"
    t.index ["workspace_id", "transacted_on"], name: "index_financial_transactions_on_workspace_id_and_transacted_on"
    t.index ["workspace_id"], name: "index_financial_transactions_on_workspace_id"
  end

  create_table "plans", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "includes_email_channel", default: false, null: false
    t.boolean "includes_kpi_advanced", default: false, null: false
    t.boolean "includes_open_finance", default: false, null: false
    t.integer "max_documents_month"
    t.integer "max_users"
    t.integer "max_whatsapp_messages_month"
    t.integer "monthly_price_cents", default: 0, null: false
    t.string "name", null: false
    t.integer "setup_fee_cents", default: 0, null: false
    t.string "slug", null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_plans_on_slug", unique: true
    t.index ["status"], name: "index_plans_on_status"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "ends_at"
    t.bigint "plan_id", null: false
    t.datetime "starts_at"
    t.string "status", default: "trial", null: false
    t.datetime "trial_ends_at"
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["plan_id"], name: "index_subscriptions_on_plan_id"
    t.index ["workspace_id", "status"], name: "index_subscriptions_on_workspace_id_and_status"
    t.index ["workspace_id"], name: "index_subscriptions_on_workspace_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "workspace_users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "role", default: "member", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "workspace_id", null: false
    t.index ["user_id"], name: "index_workspace_users_on_user_id"
    t.index ["workspace_id", "user_id"], name: "index_workspace_users_on_workspace_id_and_user_id", unique: true
    t.index ["workspace_id"], name: "index_workspace_users_on_workspace_id"
  end

  create_table "workspaces", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.string "name", null: false
    t.bigint "owner_id", null: false
    t.string "status", default: "active", null: false
    t.string "tax_id"
    t.datetime "updated_at", null: false
    t.index ["owner_id"], name: "index_workspaces_on_owner_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "categories", "workspaces"
  add_foreign_key "category_rules", "workspaces"
  add_foreign_key "counterparties", "workspaces"
  add_foreign_key "document_extractions", "documents"
  add_foreign_key "document_extractions", "workspaces"
  add_foreign_key "documents", "workspaces"
  add_foreign_key "financial_transactions", "workspaces"
  add_foreign_key "subscriptions", "plans"
  add_foreign_key "subscriptions", "workspaces"
  add_foreign_key "workspace_users", "users"
  add_foreign_key "workspace_users", "workspaces"
  add_foreign_key "workspaces", "users", column: "owner_id"
end
