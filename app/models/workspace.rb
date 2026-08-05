class Workspace < ApplicationRecord
  belongs_to :owner, class_name: "User", foreign_key: :owner_id
  has_many :workspace_users, dependent: :destroy
  has_many :users, through: :workspace_users
  has_one :subscription, dependent: :destroy
  has_many :categories, dependent: :destroy
  has_many :counterparties, dependent: :destroy
  has_many :documents, dependent: :destroy
  has_many :document_extractions, dependent: :destroy
  has_many :financial_transactions, dependent: :destroy
  has_many :workspace_channels, dependent: :destroy
  has_many :incoming_messages, dependent: :destroy
  has_many :outgoing_messages, dependent: :destroy
  has_many :consents, dependent: :destroy
  has_many :bank_accounts, dependent: :destroy
  has_many :bank_transactions, dependent: :destroy
  has_many :reconciliation_matches, dependent: :destroy
  has_many :ai_interactions, dependent: :nullify
  has_many :kpi_snapshots, dependent: :destroy
  has_many :insights, dependent: :destroy
  has_many :workspace_memories, dependent: :destroy
  has_many :agent_messages, dependent: :destroy

  enum :kind, { cpf: "cpf", mei: "mei", empresa: "empresa" }
  enum :status, { active: "active", suspended: "suspended", trial: "trial" }

  validates :name, :kind, presence: true
  # tax_id NUNCA obrigatório
  validates :tax_id, cpf_cnpj: true, allow_blank: true
  # Número de WhatsApp que identifica o remetente no número global do Aionis.
  # Opcional; único quando informado (um número pertence a um workspace).
  validates :whatsapp_number, uniqueness: true, allow_blank: true

  before_validation :normalize_whatsapp_number
  after_create :add_owner_as_member

  # Celular brasileiro: 55 + DDD + 9 dígitos (com o "9") ou 8 (sem).
  BR_MOBILE_WITH_9    = /\A55(\d{2})9(\d{8})\z/
  BR_MOBILE_WITHOUT_9 = /\A55(\d{2})(\d{8})\z/

  # Mesmos formatos SEM o DDI, que é como o brasileiro digita no portal
  # ("(12) 99604-9308"). DDD nunca tem zero, e celular sempre começa com 9 —
  # é o que evita confundir um número estrangeiro de 11 dígitos com um BR.
  BR_LOCAL_WITH_9    = /\A([1-9][1-9])9(\d{8})\z/
  BR_LOCAL_WITHOUT_9 = /\A([1-9][1-9])(\d{8})\z/

  # Formas equivalentes do mesmo número. A Meta entrega o wa_id de celulares
  # brasileiros ora COM, ora SEM o "9" adicional (depende de quando a linha foi
  # registrada no WhatsApp) — e não é o mesmo formato que o cliente digita no
  # portal. Guardamos um número só, mas aceitamos as duas formas ao identificar
  # o remetente; sem isso o bot ignora silenciosamente quem escreve.
  def self.whatsapp_number_variants(number)
    digits = number.to_s.gsub(/\D/, "").presence
    return [] if digits.blank?

    variants = [ digits ]
    if (m = digits.match(BR_MOBILE_WITH_9))
      variants << "55#{m[1]}#{m[2]}"
    elsif (m = digits.match(BR_MOBILE_WITHOUT_9))
      variants << "55#{m[1]}9#{m[2]}"
    end
    variants.uniq
  end

  # Acha o workspace do remetente tolerando o 9º dígito. Prefere sempre a
  # correspondência exata quando as duas formas existirem no banco.
  def self.find_by_whatsapp_number(number)
    variants = whatsapp_number_variants(number)
    return nil if variants.empty?

    found = where(whatsapp_number: variants).to_a
    found.find { |w| w.whatsapp_number == variants.first } || found.first
  end

  # Forma canônica: só dígitos e SEMPRE com DDI, que é como a Meta entrega o
  # remetente no webhook (wa_id "5512996049308"). Sem isso, quem cadastra no
  # formato brasileiro comum — "(12) 99604-9308" — vira "12996049308", nunca
  # casa com o wa_id e é descartado em silêncio pelo InboundProcessor (nem
  # IncomingMessage é gravada). É a falha mais cara possível: o cliente só vê
  # o bot não responder.
  #
  # Números que já têm DDI (12–13 dígitos) e os que não parecem brasileiros
  # passam intactos — só normalizamos o que reconhecemos como BR local.
  def self.canonical_whatsapp_number(number)
    digits = number.to_s.gsub(/\D/, "").presence
    return nil if digits.blank?

    digits.match?(BR_LOCAL_WITH_9) || digits.match?(BR_LOCAL_WITHOUT_9) ? "55#{digits}" : digits
  end

  private

  def normalize_whatsapp_number
    return if whatsapp_number.blank?

    self.whatsapp_number = self.class.canonical_whatsapp_number(whatsapp_number)
  end

  def add_owner_as_member
    workspace_users.find_or_create_by(user: owner) { |wu| wu.role = "owner" }
  end
end
