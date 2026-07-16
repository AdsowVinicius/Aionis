require "test_helper"

class Workspaces::FinancialTransactionsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(
      name: "Ctrl Test",
      email: "ft_ctrl_#{SecureRandom.hex(4)}@aionis.test",
      password: "senha1234"
    )
    @workspace = Workspace.create!(name: "WS Ctrl", kind: "empresa", owner: @user)
    sign_in @user
  end

  # 1. Cria lançamento manual sem document_id
  test "cria lançamento manual sem document_id" do
    assert_difference("FinancialTransaction.count") do
      post workspace_financial_transactions_path(@workspace), params: {
        financial_transaction: {
          kind: "expense",
          description: "Compra de material na loja do bairro",
          amount_brl: "120,50",
          status: "pending"
        }
      }
    end
    assert_redirected_to workspace_financial_transactions_path(@workspace)
    assert_nil FinancialTransaction.last.document_id
  end

  # 2. Cria lançamento manual sem counterparty_id
  test "cria lançamento manual sem counterparty_id" do
    assert_difference("FinancialTransaction.count") do
      post workspace_financial_transactions_path(@workspace), params: {
        financial_transaction: {
          kind: "expense",
          description: "Aluguel do escritório",
          amount_brl: "1.500,00",
          status: "pending"
        }
      }
    end
    assert_nil FinancialTransaction.last.counterparty_id
  end

  # 3. Cria lançamento manual sem category_id
  test "cria lançamento manual sem category_id" do
    assert_difference("FinancialTransaction.count") do
      post workspace_financial_transactions_path(@workspace), params: {
        financial_transaction: {
          kind: "income",
          description: "Receita de consultoria",
          amount_brl: "500",
          status: "confirmed"
        }
      }
    end
    assert_nil FinancialTransaction.last.category_id
  end

  # 4. Conversão de valor BR para centavos
  test "amount_brl converte 1.200,50 para 120050 centavos" do
    post workspace_financial_transactions_path(@workspace), params: {
      financial_transaction: {
        kind: "expense",
        description: "Teste de conversão",
        amount_brl: "1.200,50",
        status: "pending"
      }
    }
    assert_equal 120_050, FinancialTransaction.last.amount_cents
  end

  test "amount_brl converte 120,50 para 12050 centavos" do
    post workspace_financial_transactions_path(@workspace), params: {
      financial_transaction: {
        kind: "expense",
        description: "Teste de conversão decimal",
        amount_brl: "120,50",
        status: "pending"
      }
    }
    assert_equal 12_050, FinancialTransaction.last.amount_cents
  end

  test "amount_brl converte 120 para 12000 centavos" do
    post workspace_financial_transactions_path(@workspace), params: {
      financial_transaction: {
        kind: "income",
        description: "Teste valor inteiro",
        amount_brl: "120",
        status: "pending"
      }
    }
    assert_equal 12_000, FinancialTransaction.last.amount_cents
  end

  # 5. Lançamento pertence ao workspace correto
  test "lançamento criado pertence ao workspace do usuário" do
    post workspace_financial_transactions_path(@workspace), params: {
      financial_transaction: {
        kind: "expense",
        description: "Despesa de teste",
        amount_brl: "100",
        status: "pending"
      }
    }
    assert_equal @workspace.id, FinancialTransaction.last.workspace_id
  end

  # 6. Isolamento multi-tenant: não acessa lançamento de outro workspace
  test "não acessa lançamento de outro workspace" do
    other_user = User.create!(
      name: "Outro",
      email: "other_#{SecureRandom.hex(4)}@aionis.test",
      password: "senha1234"
    )
    other_workspace = Workspace.create!(name: "Outro WS", kind: "cpf", owner: other_user)
    other_tx = other_workspace.financial_transactions.create!(
      kind: "expense",
      description: "Lançamento de outro workspace",
      amount_cents: 5_000,
      origin: "manual",
      status: "pending"
    )

    get workspace_financial_transaction_path(@workspace, other_tx)
    assert_response :not_found
  end

  # 7. Origin é sempre forçado como "manual"
  test "origin é sempre manual independente do parâmetro enviado" do
    post workspace_financial_transactions_path(@workspace), params: {
      financial_transaction: {
        kind: "income",
        description: "Origem deve ser manual",
        amount_brl: "200",
        status: "pending",
        origin: "import"
      }
    }
    assert_equal "manual", FinancialTransaction.last.origin
  end

  # --- Testes de renderização (GET) ---

  test "GET index renderiza com sucesso" do
    get workspace_financial_transactions_path(@workspace)
    assert_response :success
  end

  test "GET new renderiza com sucesso" do
    get new_workspace_financial_transaction_path(@workspace)
    assert_response :success
  end

  test "GET show renderiza com sucesso" do
    tx = @workspace.financial_transactions.create!(
      kind: "expense", description: "Lançamento para show",
      amount_cents: 9_900, origin: "manual", status: "pending"
    )
    get workspace_financial_transaction_path(@workspace, tx)
    assert_response :success
  end

  test "GET edit renderiza com sucesso" do
    tx = @workspace.financial_transactions.create!(
      kind: "income", description: "Lançamento para edit",
      amount_cents: 15_000, origin: "manual", status: "confirmed"
    )
    get edit_workspace_financial_transaction_path(@workspace, tx)
    assert_response :success
  end

  # Conversão adicional: "120.50" (ponto como decimal, sem vírgula)
  test "amount_brl converte 120.50 para 12050 centavos" do
    post workspace_financial_transactions_path(@workspace), params: {
      financial_transaction: {
        kind: "expense",
        description: "Teste ponto como decimal",
        amount_brl: "120.50",
        status: "pending"
      }
    }
    assert_equal 12_050, FinancialTransaction.last.amount_cents
  end

  # ─── Testes de vínculo manual (etapa: vínculos) ───────────────────────────

  # V1. Form de novo lançamento renderiza com selects de categoria, fornecedor e documento
  test "GET new renderiza selects de vínculo" do
    get new_workspace_financial_transaction_path(@workspace)
    assert_response :success
    assert_match "category_id",     response.body
    assert_match "counterparty_id", response.body
    assert_match "document_id",     response.body
  end

  # V2. Cria lançamento com documento do mesmo workspace
  test "POST create com document_id do mesmo workspace vincula documento" do
    doc = @workspace.documents.new(source: "web", status: "pending")
    doc.save!(validate: false)

    assert_difference("FinancialTransaction.count") do
      post workspace_financial_transactions_path(@workspace), params: {
        financial_transaction: {
          kind: "expense", description: "Compra vinculada",
          amount_brl: "200", status: "pending", document_id: doc.id
        }
      }
    end
    assert_equal doc.id, FinancialTransaction.last.document_id
  end

  # V2b. new?document_id pré-preenche o formulário a partir da extração fiscal
  test "GET new com document_id pré-preenche dados da extração de XML" do
    doc = @workspace.documents.new(source: "web", status: "review")
    doc.save!(validate: false)
    doc.document_extractions.create!(
      workspace_id: @workspace.id,
      status: "extracted",
      processor_name: "fiscal_xml_parser",
      confidence_score: 100,
      suggested_transaction_data: {
        "kind" => "expense",
        "description" => "Loja do Bairro — NF 123",
        "amount_cents" => 15_000,
        "transacted_on" => "2024-01-15",
        "counterparty_name_snapshot" => "Loja do Bairro Comercio LTDA",
        "counterparty_tax_id_snapshot" => "11.222.333/0001-81",
        "counterparty_tax_id_status" => "informed"
      }
    )

    get new_workspace_financial_transaction_path(@workspace, document_id: doc.id)
    assert_response :success
    assert_match "Loja do Bairro — NF 123", response.body
    assert_match "Loja do Bairro Comercio LTDA", response.body
    # valor 15000 centavos = 150,00 pré-preenchido no campo
    assert_match "150,00", response.body
  end

  # V2c. Prefill vincula fornecedor existente quando CNPJ confere
  test "GET new com document_id vincula fornecedor existente pelo CNPJ" do
    cp = @workspace.counterparties.create!(
      name: "Loja do Bairro", kind: "supplier", tax_id: "11.222.333/0001-81"
    )
    doc = @workspace.documents.new(source: "web", status: "review")
    doc.save!(validate: false)
    doc.document_extractions.create!(
      workspace_id: @workspace.id, status: "extracted",
      suggested_transaction_data: {
        "amount_cents" => 15_000,
        "counterparty_tax_id_snapshot" => "11.222.333/0001-81"
      }
    )

    get new_workspace_financial_transaction_path(@workspace, document_id: doc.id)
    assert_response :success
    # o select de fornecedor deve vir com o fornecedor existente selecionado
    assert_match(/option selected[^>]*value="#{cp.id}"|value="#{cp.id}"[^>]*selected/, response.body)
  end

  # C1. Motor classifica automaticamente ao criar (regra por palavra-chave)
  test "POST create classifica automaticamente via regra" do
    cat = Category.create!(name: "Energia CTRL", kind: "expense",
                           cost_type: "fixed", essentiality: "essential")
    CategoryRule.create!(name: "Energia CTRL rule", keywords: "energia, luz",
                         kind: "expense", category: cat, recurrence: "recurring", confidence: 80)

    post workspace_financial_transactions_path(@workspace), params: {
      financial_transaction: {
        kind: "expense", description: "Conta de energia eletrica", amount_brl: "300", status: "pending"
      }
    }
    tx = FinancialTransaction.last
    assert_equal cat.id, tx.category_id
    assert_equal "fixed", tx.cost_type
    assert_equal "essential", tx.essentiality
    assert_equal "recurring", tx.recurrence
    assert_equal "rule", tx.classification_source
    assert_operator tx.classification_confidence, :>=, 61
    assert tx.classification_reasons.present?
  end

  # C2. Categoria escolhida manualmente = correção (source manual, confiança 100)
  test "POST create com categoria manual marca classificação manual" do
    cat = Category.create!(name: "Software CTRL", kind: "expense",
                           cost_type: "fixed", essentiality: "operational_important")

    post workspace_financial_transactions_path(@workspace), params: {
      financial_transaction: {
        kind: "expense", description: "Assinatura qualquer", amount_brl: "50",
        status: "pending", category_id: cat.id
      }
    }
    tx = FinancialTransaction.last
    assert_equal cat.id, tx.category_id
    assert_equal "manual", tx.classification_source
    assert_equal 100, tx.classification_confidence
    assert_equal "fixed", tx.cost_type
  end

  # C3. Sem regra nem histórico: cria normalmente, sem categoria (source none)
  test "POST create sem match cria lançamento sem categoria" do
    assert_difference("FinancialTransaction.count") do
      post workspace_financial_transactions_path(@workspace), params: {
        financial_transaction: {
          kind: "expense", description: "xyzabc sem correspondencia", amount_brl: "10", status: "pending"
        }
      }
    end
    tx = FinancialTransaction.last
    assert_nil tx.category_id
    assert_equal "none", tx.classification_source
  end

  # V3. Cria lançamento com fornecedor/cliente do mesmo workspace
  test "POST create com counterparty_id do mesmo workspace vincula fornecedor" do
    cp = @workspace.counterparties.create!(name: "Fornecedor Vínculo", kind: "supplier")

    assert_difference("FinancialTransaction.count") do
      post workspace_financial_transactions_path(@workspace), params: {
        financial_transaction: {
          kind: "expense", description: "Pagamento fornecedor",
          amount_brl: "500", status: "pending", counterparty_id: cp.id
        }
      }
    end
    assert_equal cp.id, FinancialTransaction.last.counterparty_id
  end

  # V4. Cria lançamento com categoria global do sistema
  test "POST create com categoria global vincula categoria" do
    global_cat = Category.create!(name: "Global Vínculo #{SecureRandom.hex(4)}", kind: "expense")

    assert_difference("FinancialTransaction.count") do
      post workspace_financial_transactions_path(@workspace), params: {
        financial_transaction: {
          kind: "expense", description: "Despesa com categoria global",
          amount_brl: "300", status: "pending", category_id: global_cat.id
        }
      }
    end
    assert_equal global_cat.id, FinancialTransaction.last.category_id
  end

  # V5. Cria lançamento com categoria do próprio workspace
  test "POST create com categoria do workspace vincula categoria" do
    cat = @workspace.categories.create!(name: "Categoria WS Vínculo", kind: "expense")

    assert_difference("FinancialTransaction.count") do
      post workspace_financial_transactions_path(@workspace), params: {
        financial_transaction: {
          kind: "expense", description: "Despesa com categoria custom",
          amount_brl: "150", status: "pending", category_id: cat.id
        }
      }
    end
    assert_equal cat.id, FinancialTransaction.last.category_id
  end

  # V6. Não aceita documento de outro workspace
  test "POST create com document_id de outro workspace é rejeitado" do
    other_user = User.create!(
      name: "Outro Doc", email: "otherdoc_#{SecureRandom.hex(4)}@aionis.test", password: "senha1234"
    )
    other_ws = Workspace.create!(name: "WS Other Doc", kind: "cpf", owner: other_user)
    other_doc = other_ws.documents.new(source: "web", status: "pending")
    other_doc.save!(validate: false)

    assert_no_difference("FinancialTransaction.count") do
      post workspace_financial_transactions_path(@workspace), params: {
        financial_transaction: {
          kind: "expense", description: "Tentativa cross-doc",
          amount_brl: "100", status: "pending", document_id: other_doc.id
        }
      }
    end
    assert_response :unprocessable_entity
  end

  # V7. Não aceita fornecedor de outro workspace
  test "POST create com counterparty_id de outro workspace é rejeitado" do
    other_user = User.create!(
      name: "Outro CP", email: "othercp_#{SecureRandom.hex(4)}@aionis.test", password: "senha1234"
    )
    other_ws = Workspace.create!(name: "WS Other CP", kind: "cpf", owner: other_user)
    other_cp = other_ws.counterparties.create!(name: "Fornecedor Alheio", kind: "supplier")

    assert_no_difference("FinancialTransaction.count") do
      post workspace_financial_transactions_path(@workspace), params: {
        financial_transaction: {
          kind: "expense", description: "Tentativa cross-cp",
          amount_brl: "100", status: "pending", counterparty_id: other_cp.id
        }
      }
    end
    assert_response :unprocessable_entity
  end

  # V8. Não aceita categoria personalizada de outro workspace
  test "POST create com categoria personalizada de outro workspace é rejeitada" do
    other_user = User.create!(
      name: "Outro Cat", email: "othercat_#{SecureRandom.hex(4)}@aionis.test", password: "senha1234"
    )
    other_ws = Workspace.create!(name: "WS Other Cat", kind: "cpf", owner: other_user)
    other_cat = other_ws.categories.create!(name: "Categoria Alheia", kind: "expense")

    assert_no_difference("FinancialTransaction.count") do
      post workspace_financial_transactions_path(@workspace), params: {
        financial_transaction: {
          kind: "expense", description: "Tentativa cross-cat",
          amount_brl: "100", status: "pending", category_id: other_cat.id
        }
      }
    end
    assert_response :unprocessable_entity
  end

  # V9. New com document_id válido pré-seleciona documento
  test "GET new com document_id válido pré-seleciona documento" do
    doc = @workspace.documents.new(source: "web", status: "pending")
    doc.save!(validate: false)

    get new_workspace_financial_transaction_path(@workspace), params: { document_id: doc.id }
    assert_response :success
    assert_match doc.id.to_s, response.body
  end

  # V10. New com counterparty_id válido pré-seleciona fornecedor
  test "GET new com counterparty_id válido pré-seleciona fornecedor" do
    cp = @workspace.counterparties.create!(name: "Fornecedor Prefill", kind: "client")

    get new_workspace_financial_transaction_path(@workspace), params: { counterparty_id: cp.id }
    assert_response :success
    assert_match cp.id.to_s, response.body
  end

  # V11. New com category_id válido pré-seleciona categoria
  test "GET new com category_id válido pré-seleciona categoria" do
    cat = @workspace.categories.create!(name: "Cat Prefill", kind: "income")

    get new_workspace_financial_transaction_path(@workspace), params: { category_id: cat.id }
    assert_response :success
    assert_match cat.id.to_s, response.body
  end

  # V12. New com document_id de outro workspace retorna 404
  test "GET new com document_id de outro workspace retorna 404" do
    other_user = User.create!(
      name: "Outro New", email: "othernew_#{SecureRandom.hex(4)}@aionis.test", password: "senha1234"
    )
    other_ws = Workspace.create!(name: "WS Other New", kind: "cpf", owner: other_user)
    other_doc = other_ws.documents.new(source: "web", status: "pending")
    other_doc.save!(validate: false)

    get new_workspace_financial_transaction_path(@workspace), params: { document_id: other_doc.id }
    assert_response :not_found
  end

  # V13. Show do lançamento mostra documento, fornecedor e categoria vinculados
  test "GET show exibe vínculos do lançamento" do
    doc = @workspace.documents.new(source: "web", status: "pending")
    doc.save!(validate: false)
    cp  = @workspace.counterparties.create!(name: "Forn Show", kind: "supplier")
    cat = @workspace.categories.create!(name: "Cat Show", kind: "expense")

    tx = @workspace.financial_transactions.create!(
      kind: "expense", description: "Lançamento com vínculos",
      amount_cents: 9_000, origin: "manual", status: "pending",
      document: doc, counterparty: cp, category: cat
    )

    get workspace_financial_transaction_path(@workspace, tx)
    assert_response :success
    assert_match "Forn Show",    response.body
    assert_match "Cat Show",     response.body
    assert_match doc.id.to_s,   response.body
  end

  # V14. Excluir documento não exclui lançamento; category e counterparty também
  test "excluir documento, fornecedor e categoria não exclui lançamento" do
    doc = @workspace.documents.new(source: "web", status: "pending")
    doc.save!(validate: false)
    cp  = @workspace.counterparties.create!(name: "Forn Del", kind: "supplier")
    cat = @workspace.categories.create!(name: "Cat Del", kind: "expense")

    tx = @workspace.financial_transactions.create!(
      kind: "expense", description: "Lançamento para teste de cascata",
      amount_cents: 1_000, origin: "manual", status: "pending",
      document: doc, counterparty: cp, category: cat
    )

    doc.destroy
    cp.destroy
    cat.destroy

    assert FinancialTransaction.exists?(tx.id)
    tx.reload
    assert_nil tx.document_id
    assert_nil tx.counterparty_id
    assert_nil tx.category_id
  end

  # 8. Dashboard calcula receitas e despesas do mês atual
  test "dashboard exibe dados reais do mês atual" do
    @workspace.financial_transactions.create!(
      kind: "income", description: "Receita mês atual",
      amount_cents: 50_000, origin: "manual", status: "confirmed",
      transacted_on: Date.current
    )
    @workspace.financial_transactions.create!(
      kind: "expense", description: "Despesa mês atual",
      amount_cents: 20_000, origin: "manual", status: "confirmed",
      transacted_on: Date.current
    )
    # Lançamento de outro mês não deve entrar nos cards do mês
    @workspace.financial_transactions.create!(
      kind: "income", description: "Receita mês passado",
      amount_cents: 999_999, origin: "manual", status: "confirmed",
      transacted_on: 2.months.ago.to_date
    )

    get workspace_dashboard_path(@workspace)
    assert_response :success
  end

  # 9. Correção manual de categoria ensina uma regra de classificação
  test "classificar manualmente cria regra aprendida e classifica o próximo igual" do
    categoria = Category.create!(name: "Transporte #{SecureRandom.hex(2)}", kind: "expense",
                                 cost_type: "variable", essentiality: "operational_important")
    fornecedor = @workspace.counterparties.create!(name: "Posto Aprendiz", kind: "supplier")

    assert_difference -> { CategoryRule.learned.where(workspace_id: @workspace.id).count }, 1 do
      post workspace_financial_transactions_path(@workspace), params: {
        financial_transaction: {
          kind: "expense", description: "abastecimento", amount_brl: "80,00",
          status: "confirmed", counterparty_id: fornecedor.id, category_id: categoria.id
        }
      }
    end

    regra = CategoryRule.learned.find_by(workspace_id: @workspace.id, counterparty_id: fornecedor.id)
    assert_equal categoria.id, regra.category_id

    # Próximo lançamento do mesmo fornecedor já é sugerido automaticamente
    get new_workspace_financial_transaction_path(@workspace), params: {
      counterparty_id: fornecedor.id
    }
    assert_response :success
    tx = @workspace.financial_transactions.new(description: "novo abastecimento",
                                               kind: "expense", counterparty: fornecedor)
    sugestao = Aionis::ClassificationEngine.for_transaction(tx).call
    assert_equal categoria.id, sugestao.category_id
  end
end
