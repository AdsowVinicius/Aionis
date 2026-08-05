# frozen_string_literal: true

# Números cadastrados antes da normalização canônica ficaram sem o DDI
# ("12996049308"), então nunca casavam com o wa_id que a Meta entrega
# ("5512996049308") e o remetente era descartado em silêncio.
#
# Reescreve as linhas antigas para a forma canônica. Colisão (a forma com DDI
# já existir em outro workspace) é deixada intacta e avisada: o índice único
# parcial de whatsapp_number impede a escrita, e escolher qual dos dois fica
# com o número é decisão de negócio, não de migração.
class BackfillWhatsappNumberDdi < ActiveRecord::Migration[8.1]
  def up
    Workspace.reset_column_information

    Workspace.where.not(whatsapp_number: nil).find_each do |workspace|
      atual     = workspace.whatsapp_number.to_s
      canonico  = Workspace.canonical_whatsapp_number(atual)
      next if canonico.blank? || canonico == atual

      if Workspace.where(whatsapp_number: canonico).where.not(id: workspace.id).exists?
        say "workspace ##{workspace.id}: #{atual} -> #{canonico} PULADO (já existe em outro workspace)"
        next
      end

      workspace.update_column(:whatsapp_number, canonico)
      say "workspace ##{workspace.id}: #{atual} -> #{canonico}"
    end
  end

  # Irreversível por escolha: o formato sem DDI é justamente o defeito que a
  # migração corrige, e não há como saber quais linhas já vieram com DDI.
  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
