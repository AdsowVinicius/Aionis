require "test_helper"

class Aionis::Agent::MemoryCardTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(name: "M", email: "mem_#{SecureRandom.hex(4)}@t.test", password: "senha1234")
    @workspace = Workspace.create!(name: "WS", kind: "mei", owner: @user)
  end

  test "injeta top-N por relevância" do
    WorkspaceMemory.remember!(@workspace, key: "menos", value: "fato menos relevante", relevance: 1)
    WorkspaceMemory.remember!(@workspace, key: "mais", value: "fato mais relevante", relevance: 90)

    card = Aionis::Agent::MemoryCard.call(@workspace)
    assert card.index("mais") < card.index("menos"), "mais relevante deveria vir primeiro"
  end

  test "respeita o teto de tokens cortando os menos relevantes" do
    WorkspaceMemory.remember!(@workspace, key: "essencial", value: "x" * 100, relevance: 100)
    WorkspaceMemory.remember!(@workspace, key: "cortavel", value: "y" * 400, relevance: 1)

    # Orçamento minúsculo: só o mais relevante cabe (40 tokens ≈ 160 chars;
    # o fato de 400+ chars estoura e é cortado)
    card = Aionis::Agent::MemoryCard.call(@workspace, token_budget: 40)
    assert_includes card, "essencial"
    refute_includes card, "cortavel"
  end

  test "workspace sem memórias devolve string vazia" do
    assert_equal "", Aionis::Agent::MemoryCard.call(@workspace)
  end

  test "marca fatos inferidos como não confiáveis" do
    WorkspaceMemory.remember!(@workspace, key: "ramo", value: "construção", source: "inferred", relevance: 10)
    card = Aionis::Agent::MemoryCard.call(@workspace)
    assert_includes card, "(inferido)"
    assert_includes card, "não trate como verdade absoluta"
  end

  test "não vaza memórias de outro workspace" do
    other = Workspace.create!(name: "Outro", kind: "cpf", owner: @user)
    WorkspaceMemory.remember!(other, key: "segredo", value: "dado de outro cliente", relevance: 100)

    assert_equal "", Aionis::Agent::MemoryCard.call(@workspace)
  end
end
