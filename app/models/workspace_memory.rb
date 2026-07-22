# Fato memorizado do workspace para o Agente Financeiro (LGPD: o cliente pode
# ver e apagar tudo pelo portal). `source` distingue o que o usuário AFIRMOU
# (user_stated) do que foi INFERIDO (inferred) — inferência nunca é verdade
# absoluta. `relevance` ordena o que entra no cartão de memória do prompt.
class WorkspaceMemory < ApplicationRecord
  belongs_to :workspace

  SOURCES = %w[user_stated inferred system].freeze

  validates :key, :value, presence: true
  validates :source, inclusion: { in: SOURCES }
  validates :key, length: { maximum: 100 }
  validates :value, length: { maximum: 500 } # fato compacto — nunca um blob

  scope :by_relevance, -> { order(relevance: :desc, updated_at: :desc) }

  # Upsert por chave dentro do workspace (uma chave = um fato atual).
  def self.remember!(workspace, key:, value:, source: "user_stated", relevance: 50)
    memory = workspace.workspace_memories.find_or_initialize_by(key: key.to_s.strip.downcase)
    memory.assign_attributes(value: value.to_s.strip, source: source, relevance: relevance)
    memory.save!
    memory
  end
end
