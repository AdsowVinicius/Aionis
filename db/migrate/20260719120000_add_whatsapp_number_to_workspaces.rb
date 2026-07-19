class AddWhatsappNumberToWorkspaces < ActiveRecord::Migration[8.1]
  def change
    # Número de WhatsApp do cliente (só dígitos, com DDI). Identifica o remetente
    # das mensagens recebidas no número global do Aionis. Opcional e único.
    add_column :workspaces, :whatsapp_number, :string
    add_index  :workspaces, :whatsapp_number, unique: true, where: "whatsapp_number IS NOT NULL"
  end
end
