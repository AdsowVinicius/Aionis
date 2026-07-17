require "test_helper"

class KpiSnapshotAndInsightTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(name: "K", email: "kpi_#{SecureRandom.hex(4)}@t.test", password: "senha1234")
    @ws = Workspace.create!(name: "WS", kind: "empresa", owner: @user)
  end

  test "KpiSnapshot exige period_label único por workspace" do
    @ws.kpi_snapshots.create!(period_label: "2026-07")
    dup = @ws.kpi_snapshots.build(period_label: "2026-07")
    refute dup.valid?
  end

  test "Insight valida severity e status" do
    i = @ws.insights.build(kind: "x", severity: "invalida")
    refute i.valid?
    ok = @ws.insights.create!(kind: "x", severity: "warning", title: "t", message: "m")
    assert ok.active?
  end

  test "workspace destrói snapshots e insights em cascata" do
    @ws.kpi_snapshots.create!(period_label: "2026-07")
    @ws.insights.create!(kind: "x", severity: "info")
    assert_difference -> { KpiSnapshot.count } => -1, -> { Insight.count } => -1 do
      @ws.destroy
    end
  end
end
