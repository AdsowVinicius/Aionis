require "yaml"

puts "\n=== Aionis Seeds ===\n\n"

# ---------------------------------------------------------------------------
# Planos — carregados de config/aionis/plans.yml
# Idempotente: find_or_initialize_by slug + save
# ---------------------------------------------------------------------------
plans_config = YAML.load_file(Rails.root.join("config", "aionis", "plans.yml"))

puts "--- Planos ---"
plans_config.each do |slug, attrs|
  plan = Plan.find_or_initialize_by(slug: slug)
  novo = plan.new_record?
  plan.assign_attributes(
    name:                      attrs["name"],
    monthly_price_cents:       attrs["monthly_price_cents"],
    setup_fee_cents:           attrs["setup_fee_cents"] || 0,
    max_documents_month:       attrs["max_documents_month"],
    max_whatsapp_messages_month: attrs["max_whatsapp_messages_month"],
    max_users:                 attrs["max_users"],
    includes_email_channel:    attrs["includes_email_channel"] || false,
    includes_kpi_advanced:     attrs["includes_kpi_advanced"] || false,
    includes_open_finance:     attrs["includes_open_finance"] || false,
    status:                    attrs["status"] || "active"
  )
  plan.save!
  acao = novo ? "criado" : "atualizado"
  puts "  [#{acao}] #{plan.name} (slug: #{slug}) — R$ #{format('%.2f', plan.monthly_price_brl)}/mês"
end

puts "\nTotal de planos: #{Plan.count}\n\n"

# ---------------------------------------------------------------------------
# Categorias globais — carregadas de config/aionis/categories.yml
# workspace_id nulo = categoria global do sistema
# Idempotente: find_or_initialize_by name + workspace_id nil
# Primeira passada: cria/atualiza sem parent
# Segunda passada: resolve referências de parent
# ---------------------------------------------------------------------------
categories_config = YAML.load_file(Rails.root.join("config", "aionis", "categories.yml"))

puts "--- Categorias globais ---"

# Passada 1: criar/atualizar sem parent
categories_config.each do |_key, attrs|
  cat = Category.find_or_initialize_by(name: attrs["name"], workspace_id: nil)
  novo = cat.new_record?
  cat.assign_attributes(
    kind:             attrs["kind"],
    cost_type:        attrs["cost_type"],
    essentiality:     attrs["essentiality"],
    is_system_default: attrs.fetch("is_system_default", false)
  )
  cat.save!
  acao = novo ? "criada" : "atualizada"
  puts "  [#{acao}] #{cat.name}"
end

# Passada 2: resolver parents
categories_config.each do |_key, attrs|
  next unless attrs["parent"]

  cat    = Category.find_by!(name: attrs["name"], workspace_id: nil)
  parent = Category.find_by!(name: attrs["parent"], workspace_id: nil)

  if cat.parent_id != parent.id
    cat.update!(parent_id: parent.id)
    puts "  [parent] #{cat.name} → #{parent.name}"
  end
end

puts "\nTotal de categorias globais: #{Category.global.count}\n\n"
puts "=== Seeds concluídos ===\n"
