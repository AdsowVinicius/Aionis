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

# ---------------------------------------------------------------------------
# Regras globais de classificação — carregadas de config/aionis/category_rules.yml
# workspace_id nulo = regra global. Idempotente: find_or_initialize_by name (global).
# category: nome exato de uma categoria global.
# ---------------------------------------------------------------------------
rules_path = Rails.root.join("config", "aionis", "category_rules.yml")

if File.exist?(rules_path)
  rules_config = YAML.load_file(rules_path)

  puts "--- Regras globais de classificação ---"
  rules_config.each do |_key, attrs|
    category =
      if attrs["category"].present?
        Category.find_by(name: attrs["category"], workspace_id: nil)
      end

    if attrs["category"].present? && category.nil?
      puts "  [ignorada] #{attrs['name']} — categoria '#{attrs['category']}' não encontrada"
      next
    end

    rule = CategoryRule.find_or_initialize_by(name: attrs["name"], workspace_id: nil)
    novo = rule.new_record?
    rule.assign_attributes(
      origin:       "seed",
      priority:     attrs["priority"] || 0,
      active:       attrs.fetch("active", true),
      kind:         attrs["kind"],
      keywords:     attrs["keywords"],
      category_id:  category&.id,
      cost_type:    attrs["cost_type"],
      essentiality: attrs["essentiality"],
      scope:        attrs["scope"],
      recurrence:   attrs["recurrence"],
      cost_center:  attrs["cost_center"],
      confidence:   attrs["confidence"] || 70
    )
    rule.save!
    acao = novo ? "criada" : "atualizada"
    puts "  [#{acao}] #{rule.name} (prioridade #{rule.priority})"
  end

  puts "\nTotal de regras globais: #{CategoryRule.global.count}\n\n"
end

puts "=== Seeds concluídos ===\n"
