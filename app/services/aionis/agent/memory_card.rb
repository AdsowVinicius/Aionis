# frozen_string_literal: true

module Aionis
  module Agent
    # Monta o "cartão de memória" do system prompt: os top-N fatos do workspace
    # por relevância, com TETO RÍGIDO de tokens (aprox. 4 chars/token). Se
    # estourar, corta pelos de menor relevância. Nunca injeta a conversa bruta.
    class MemoryCard
      DEFAULT_TOKEN_BUDGET = 500
      CHARS_PER_TOKEN      = 4
      MAX_FACTS            = 20

      def self.call(workspace, token_budget: DEFAULT_TOKEN_BUDGET)
        new(workspace, token_budget: token_budget).call
      end

      def initialize(workspace, token_budget: DEFAULT_TOKEN_BUDGET)
        @workspace    = workspace
        @char_budget  = token_budget * CHARS_PER_TOKEN
      end

      # @return [String] bloco de texto pronto para o system prompt ("" se vazio)
      def call
        lines = []
        used  = 0

        @workspace.workspace_memories.by_relevance.limit(MAX_FACTS).each do |memory|
          line = format_fact(memory)
          break if used + line.length > @char_budget

          lines << line
          used += line.length
        end
        return "" if lines.empty?

        <<~CARD.strip
          Fatos memorizados deste cliente (fatos "inferido" podem estar errados — não trate como verdade absoluta):
          #{lines.join("\n")}
        CARD
      end

      private

      def format_fact(memory)
        tag = memory.source == "user_stated" ? "afirmado" : memory.source == "inferred" ? "inferido" : "sistema"
        "- #{memory.key}: #{memory.value} (#{tag})"
      end
    end
  end
end
