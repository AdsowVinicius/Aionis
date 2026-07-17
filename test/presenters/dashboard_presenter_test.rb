require "test_helper"

class DashboardPresenterTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(name: "P", email: "pres_#{SecureRandom.hex(4)}@t.test", password: "senha1234")
    @workspace = Workspace.create!(name: "WS", kind: "empresa", owner: @user)
    @presenter = DashboardPresenter.new(@workspace)
  end

  def tx(kind:, cents:, **extra)
    @workspace.financial_transactions.create!(kind: kind, description: "x", amount_cents: cents,
                                              origin: "manual", status: "confirmed", transacted_on: Date.current, **extra)
  end

  test "empty? verdadeiro sem lançamentos, falso com dados" do
    assert @presenter.empty?
    tx(kind: "income", cents: 10_000)
    assert_not DashboardPresenter.new(@workspace).empty?
  end

  test "delega as métricas ao Aionis::Analytics::Dashboard" do
    tx(kind: "income", cents: 100_000)
    tx(kind: "expense", cents: 60_000)

    assert_kind_of Aionis::Analytics::Kpis::Result, @presenter.kpis
    assert_equal 100_000, @presenter.kpis.income_cents
    assert_equal 12, @presenter.monthly_evolution.size
    assert_respond_to @presenter.health, :score
    assert_kind_of Array, @presenter.insights
  end

  test "expõe documentos, mensagens e contas a vencer da página" do
    doc = @workspace.documents.new(source: "web", status: "processed")
    doc.file.attach(io: StringIO.new("x"), filename: "a.png", content_type: "image/png")
    doc.save!
    channel = @workspace.workspace_channels.create!(provider: "meta_cloud", phone_number_id: "PN1")
    channel.incoming_messages.create!(workspace: @workspace, wa_message_id: "M1", kind: "document",
                                      from_number: "5511999", received_at: Time.current)
    @workspace.financial_transactions.create!(kind: "expense", description: "Aluguel", amount_cents: 50_000,
                                              origin: "manual", status: "pending", settlement_status: "open",
                                              due_on: 3.days.from_now.to_date)

    assert_equal 1, @presenter.recent_documents.size
    assert_equal 1, @presenter.recent_messages.size
    assert_equal 1, @presenter.upcoming_payables.size
    assert_respond_to @presenter.alerts, :critical_count
  end
end
