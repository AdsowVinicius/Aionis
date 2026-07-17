# frozen_string_literal: true

module Aionis
  module Analytics
    # Captura o snapshot de KPIs e gera insights de um workspace (agendável
    # mensalmente). Toda a lógica vive no SnapshotService.
    class CaptureKpiSnapshotJob < ApplicationJob
      queue_as :default

      def perform(workspace_id, on = nil)
        workspace = Workspace.find_by(id: workspace_id)
        return unless workspace

        date = on ? Date.parse(on.to_s) : Date.current
        Aionis::Analytics::SnapshotService.new(workspace, on: date).call
      end
    end
  end
end
