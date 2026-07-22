require "test_helper"

# Tools do Agente: dados corretos e SEMPRE escopadas no workspace injetado —
# um workspace jamais enxerga dados de outro (regra inegociável).
class Aionis::Agent::ToolsTest < ActiveSupport::TestCase
  setup do
    @user  = User.create!(name: "T", email: "tool_#{SecureRandom.hex(4)}@t.test", password: "senha1234")
    @ws    = Workspace.create!(name: "Meu", kind: "empresa", owner: @user)
    @other = Workspace.create!(name: "Alheio", kind: "empresa", owner: @user)

    # Meu workspace: 1 receita 1000,00 + 1 despesa 300,00 (mês atual)
    create_tx(@ws, kind: "income",  amount: 100_000, description: "Venda serviço")
    create_tx(@ws, kind: "expense", amount: 30_000,  description: "Compra material")
    # Workspace alheio: números bem diferentes — não podem vazar
    create_tx(@other, kind: "income", amount: 999_900, description: "Receita alheia")
  end

  def create_tx(ws, kind:, amount:, description:, **attrs)
    ws.financial_transactions.create!(
      kind: kind, description: description, amount_cents: amount,
      origin: "manual", status: "confirmed", transacted_on: Date.current, **attrs
    )
  end

  def run_tool(klass, args = {}, workspace: @ws, **kwargs)
    klass.new(workspace, channel: "test").call(args.merge(kwargs).stringify_keys)
  end

  test "consultar_saldo calcula receitas - despesas apenas do workspace" do
    out = run_tool(Aionis::Agent::Tools::ConsultarSaldo)
    assert_equal "R$ 1000,00", out["receitas"]
    assert_equal "R$ 300,00",  out["despesas"]
    assert_equal "R$ 700,00",  out["saldo"]
    refute out["negativo"]
  end

  test "consultar_saldo não enxerga o outro workspace" do
    out = run_tool(Aionis::Agent::Tools::ConsultarSaldo, {}, workspace: @other)
    assert_equal "R$ 9999,00", out["receitas"]
    assert_equal "R$ 0,00",    out["despesas"]
  end

  test "período inválido devolve erro amigável, nunca chuta" do
    out = run_tool(Aionis::Agent::Tools::ConsultarSaldo, periodo: "sei lá quando")
    assert_match(/não entendi o período/i, out["erro"])
  end

  test "consultar_gastos filtra por fornecedor e só no workspace" do
    cp = @ws.counterparties.create!(name: "Posto Shell", kind: "supplier")
    create_tx(@ws, kind: "expense", amount: 15_000, description: "Gasolina", counterparty: cp)

    out = run_tool(Aionis::Agent::Tools::ConsultarGastos, fornecedor: "shell")
    assert_equal "R$ 150,00", out["total"]
    assert_equal 1, out["quantidade"]
  end

  test "consultar_transacoes lista apenas do workspace e respeita limite" do
    out = run_tool(Aionis::Agent::Tools::ConsultarTransacoes, limite: 50)
    descricoes = out["lancamentos"].map { |l| l["descricao"] }
    assert_includes descricoes, "Venda serviço"
    refute_includes descricoes, "Receita alheia"
    assert_operator out["lancamentos"].size, :<=, 20 # teto rígido
  end

  test "consultar_contas devolve contas a pagar abertas e vencidas" do
    create_tx(@ws, kind: "expense", amount: 50_000, description: "Aluguel",
              settlement_status: "open", due_on: Date.current - 3)

    out = run_tool(Aionis::Agent::Tools::ConsultarContas, tipo: "pagar", status: "vencidas")
    assert_equal 1, out["quantidade"]
    assert_equal "Aluguel", out["contas"].first["descricao"]
    assert out["contas"].first["vencida"]
  end

  test "consultar_kpis reutiliza o motor de analytics escopado" do
    out = run_tool(Aionis::Agent::Tools::ConsultarKpis)
    assert_equal "R$ 1000,00", out["receitas_mes"]
    assert_equal "R$ 700,00",  out["saldo_mes"]
  end

  test "gerar_insight devolve score e insights do workspace" do
    out = run_tool(Aionis::Agent::Tools::GerarInsight)
    assert out["score_saude"].is_a?(Integer)
    assert out.key?("insights")
  end

  # --- registrar_lancamento -------------------------------------------------

  test "registrar_lancamento cria com só descrição + valor + tipo (pendente sem confirmação)" do
    out = nil
    assert_difference -> { @ws.financial_transactions.count } => 1 do
      out = run_tool(Aionis::Agent::Tools::RegistrarLancamento,
                     descricao: "Compra de material na loja do bairro", valor: "120,00", tipo: "despesa")
    end
    assert out["registrado"]
    assert_equal "pending", out["status"]
    assert_match(/pendente/i, out["observacao"])

    tx = @ws.financial_transactions.order(:id).last
    assert_equal 12_000, tx.amount_cents
    assert_equal "manual", tx.origin
    assert_nil tx.counterparty_id # fornecedor/documento/CPF seguem opcionais
  end

  test "registrar_lancamento confirmado explicitamente nasce confirmed" do
    out = run_tool(Aionis::Agent::Tools::RegistrarLancamento,
                   descricao: "Venda avulsa", valor: "250.00", tipo: "receita", confirmado: true)
    assert_equal "confirmed", out["status"]
  end

  test "registrar_lancamento rejeita valor ilegível sem criar nada" do
    assert_no_difference -> { FinancialTransaction.count } do
      out = run_tool(Aionis::Agent::Tools::RegistrarLancamento,
                     descricao: "X", valor: "muito caro", tipo: "despesa")
      assert_match(/não entendi o valor/i, out["erro"])
    end
  end

  test "registrar_lancamento grava no workspace injetado, nunca em outro" do
    run_tool(Aionis::Agent::Tools::RegistrarLancamento,
             { descricao: "Do outro", valor: "10,00", tipo: "despesa" }, workspace: @other)
    refute @ws.financial_transactions.exists?(description: "Do outro")
    assert @other.financial_transactions.exists?(description: "Do outro")
  end

  # --- memória ----------------------------------------------------------------

  test "salvar_memoria e ler_memoria escopadas no workspace" do
    run_tool(Aionis::Agent::Tools::SalvarMemoria, chave: "ramo", valor: "construção civil")

    out = run_tool(Aionis::Agent::Tools::LerMemoria)
    assert_equal [{ "chave" => "ramo", "valor" => "construção civil", "origem" => "user_stated" }], out["memorias"]

    # Outro workspace não vê nada
    alheio = run_tool(Aionis::Agent::Tools::LerMemoria, {}, workspace: @other)
    assert_equal [], alheio["memorias"]
  end

  test "salvar_memoria recusa CPF/CNPJ (LGPD)" do
    assert_no_difference -> { WorkspaceMemory.count } do
      out = run_tool(Aionis::Agent::Tools::SalvarMemoria, chave: "cliente", valor: "CPF 123.456.789-01")
      assert_match(/não memorizo/i, out["erro"])

      out2 = run_tool(Aionis::Agent::Tools::SalvarMemoria, chave: "forn", valor: "CNPJ 11222333000181")
      assert_match(/não memorizo/i, out2["erro"])
    end
  end

  test "toda tool gera AuditLog do workspace" do
    assert_difference -> { AuditLog.where(workspace_id: @ws.id, origin: "ai").count }, 1 do
      run_tool(Aionis::Agent::Tools::ConsultarSaldo)
    end
  end

  test "toolbox rejeita tool desconhecida sem exceção" do
    toolbox = Aionis::Agent::Toolbox.new(@ws)
    out = toolbox.execute("apagar_tudo", {})
    assert_match(/desconhecida/i, out["erro"])
  end
end
