# Mensagem do Agente Financeiro (histórico por workspace/canal). O orquestrador
# lê apenas uma janela deslizante (últimas N) — nunca a conversa inteira.
class AgentMessage < ApplicationRecord
  belongs_to :workspace

  CHANNELS = %w[portal whatsapp].freeze
  ROLES    = %w[user assistant].freeze

  validates :channel, inclusion: { in: CHANNELS }
  validates :role,    inclusion: { in: ROLES }
  validates :content, presence: true

  scope :for_channel, ->(channel) { where(channel: channel) }
  scope :chronological, -> { order(:created_at, :id) }

  # Últimas `limit` mensagens em ordem cronológica (janela deslizante).
  def self.window(workspace, channel:, limit:)
    where(workspace: workspace, channel: channel)
      .order(created_at: :desc, id: :desc)
      .limit(limit)
      .reverse
  end
end
