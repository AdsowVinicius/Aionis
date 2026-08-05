require "test_helper"

class WorkspaceTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(name: "WS", email: "ws_#{SecureRandom.hex(4)}@t.test", password: "senha1234")
  end

  def workspace(number)
    Workspace.create!(name: "WS", kind: "empresa", owner: @user, whatsapp_number: number)
  end

  test "normaliza o número guardando só dígitos" do
    assert_equal "5511925647469", workspace("+55 (11) 92564-7469").whatsapp_number
  end

  test "acrescenta o DDI quando o cliente cadastra no formato brasileiro" do
    assert_equal "5512996049308", workspace("(12) 99604-9308").whatsapp_number
    assert_equal "5581999679582", workspace("81999679582").whatsapp_number
  end

  test "acrescenta o DDI também quando o número vem sem o 9º dígito" do
    assert_equal "551125647469", workspace("11 2564-7469").whatsapp_number
  end

  test "não mexe em número que já tem DDI" do
    assert_equal "5511925647469", workspace("5511925647469").whatsapp_number
    assert_equal "551125647469", workspace("551125647469").whatsapp_number
  end

  test "não trata número estrangeiro como brasileiro sem DDI" do
    assert_equal "14155552671", workspace("+1 415 555 2671").whatsapp_number
  end

  test "número cadastrado sem DDI casa com o wa_id que a Meta entrega" do
    ws = workspace("(12) 99604-9308")
    assert_equal ws, Workspace.find_by_whatsapp_number("5512996049308")
  end

  test "variantes cobrem o 9º dígito dos celulares BR nos dois sentidos" do
    assert_equal %w[5511925647469 551125647469], Workspace.whatsapp_number_variants("5511925647469")
    assert_equal %w[551125647469 5511925647469], Workspace.whatsapp_number_variants("551125647469")
  end

  test "variantes não inventam formas para números não brasileiros" do
    assert_equal %w[14155552671], Workspace.whatsapp_number_variants("+1 415 555 2671")
    assert_empty Workspace.whatsapp_number_variants(nil)
    assert_empty Workspace.whatsapp_number_variants("")
  end

  test "acha o workspace mesmo quando a Meta entrega o número sem o 9" do
    ws = workspace("5511925647469")
    assert_equal ws, Workspace.find_by_whatsapp_number("551125647469")
  end

  test "acha o workspace quando o cadastro veio sem o 9 e a Meta manda com o 9" do
    ws = workspace("551125647469")
    assert_equal ws, Workspace.find_by_whatsapp_number("5511925647469")
  end

  test "prefere a correspondência exata quando as duas formas existem" do
    com_9 = workspace("5511925647469")
    sem_9 = workspace("551125647469")
    assert_equal com_9, Workspace.find_by_whatsapp_number("5511925647469")
    assert_equal sem_9, Workspace.find_by_whatsapp_number("551125647469")
  end

  test "número desconhecido não casa com ninguém" do
    workspace("5511925647469")
    assert_nil Workspace.find_by_whatsapp_number("5521988887777")
  end
end
