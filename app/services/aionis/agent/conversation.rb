# frozen_string_literal: true

module Aionis
  module Agent
    # Orquestrador ÚNICO do Agente Financeiro — WhatsApp e portal entram aqui.
    #
    # Monta o system prompt (instruções fixas + cartão de memória compacto),
    # a janela deslizante do histórico (últimas N mensagens, nunca a conversa
    # inteira) e roda o loop de tool calling contra Aionis::Integrations.ai:
    #   chama Claude -> processa tool_use -> executa tool no backend (workspace
    #   injetado) -> devolve tool_result -> repete (teto de 5 iterações).
    #
    # A LLM NUNCA acessa o banco nem gera SQL: só escolhe tools. Fora do escopo
    # das tools, o prompt manda redirecionar graciosamente — nunca inventar.
    class Conversation
      MAX_ITERATIONS      = 5
      HISTORY_WINDOW      = 10   # mensagens (user+assistant) da janela deslizante
      MEMORY_TOKEN_BUDGET = 500

      Reply = Struct.new(:text, :success, :iterations, :tools_used, keyword_init: true) do
        def success? = success
      end

      FALLBACK_UNAVAILABLE = "O assistente não está disponível no momento. " \
                             "Você pode consultar seus lançamentos e indicadores pelo painel do Aionis."
      FALLBACK_ERROR       = "Não consegui responder agora. Pode tentar de novo em instantes?"
      FALLBACK_MAX_ITER    = "Essa pergunta ficou complexa demais pra mim agora. " \
                             "Pode dividi-la em partes menores?"

      def self.call(workspace:, message:, channel: "portal", user: nil)
        new(workspace: workspace, message: message, channel: channel, user: user).call
      end

      def initialize(workspace:, message:, channel:, user: nil)
        @workspace = workspace
        @message   = message.to_s.strip
        @channel   = channel.to_s
        @user      = user
        @toolbox   = Toolbox.new(workspace, user: user, channel: @channel)
        @tools_used = []
      end

      def call
        return reply(FALLBACK_UNAVAILABLE, success: false) unless Aionis::Agent.enabled?
        return reply("Como posso ajudar com suas finanças?", success: true) if @message.blank?

        persist("user", @message)
        run_loop
      rescue => e
        Rails.logger.error("[Agent::Conversation] #{e.class}: #{e.message}")
        reply(FALLBACK_ERROR, success: false)
      end

      private

      def run_loop
        convo = window_messages

        MAX_ITERATIONS.times do |i|
          result = provider.chat(system: system_prompt, messages: convo, tools: @toolbox.definitions)
          return reply(FALLBACK_ERROR, success: false) unless result.success?

          content = result.data["content"]
          unless result.data["stop_reason"] == "tool_use"
            return finish(text_of(content), iterations: i + 1)
          end

          convo << { role: "assistant", content: content }
          convo << { role: "user", content: tool_results(content) }
        end

        finish(FALLBACK_MAX_ITER, iterations: MAX_ITERATIONS)
      end

      # Executa cada tool_use no backend e devolve os tool_results.
      def tool_results(content)
        content.select { |b| b["type"] == "tool_use" }.map do |block|
          @tools_used << block["name"]
          output = @toolbox.execute(block["name"], block["input"])
          { type: "tool_result", tool_use_id: block["id"], content: JSON.generate(output) }
        end
      end

      def finish(text, iterations:)
        text = FALLBACK_ERROR if text.blank?
        persist("assistant", text)
        audit_conversation(iterations)
        reply(text, success: true, iterations: iterations)
      end

      # --- Prompt e histórico -----------------------------------------------

      def system_prompt
        parts = [INSTRUCTIONS]
        card  = MemoryCard.call(@workspace, token_budget: MEMORY_TOKEN_BUDGET)
        parts << card if card.present?
        parts << "Canal atual: #{@channel == 'whatsapp' ? 'WhatsApp (respostas curtas, sem markdown)' : 'portal web'}."
        parts.join("\n\n")
      end

      INSTRUCTIONS = <<~PROMPT.freeze
        Você é o assistente financeiro do Aionis, um SaaS brasileiro para CPF, MEI e
        pequenas empresas. Você responde SOMENTE com base nos dados retornados pelas
        ferramentas — nunca invente números, lançamentos ou datas. Fale português
        do Brasil, de forma clara, curta e amigável; valores sempre em reais (R$).

        Regras:
        - Para responder sobre saldo, gastos, lançamentos, contas ou indicadores,
          use as ferramentas de consulta. Se a ferramenta devolver "erro", explique
          e peça o dado que faltou.
        - Para registrar um lançamento, é suficiente descrição + valor + tipo
          (receita/despesa). Se algo estiver ambíguo (valor, tipo), pergunte antes.
          Só passe confirmado=true quando o usuário confirmar explicitamente.
        - Quando o usuário afirmar um fato estável sobre o negócio (ramo,
          preferência, fornecedor principal), memorize com salvar_memoria. Nunca
          memorize CPF/CNPJ ou dados sensíveis.
        - Se a pergunta estiver fora do que as ferramentas cobrem (ex.: previsão
          do dólar, dicas de investimento, assuntos não financeiros), diga com
          gentileza que você cuida das finanças registradas no Aionis e dê exemplos
          do que sabe fazer: saldo, gastos, contas a pagar/receber, registrar
          lançamentos e insights.
        - Nunca peça nem repita dados sensíveis (senhas, cartões, CPF de terceiros).
      PROMPT

      # Janela deslizante: últimas N mensagens persistidas (inclui a atual).
      # Mescla mensagens consecutivas do mesmo papel (exigência de alternância).
      def window_messages
        AgentMessage.window(@workspace, channel: @channel, limit: HISTORY_WINDOW)
                    .map { |m| { role: m.role, content: m.content } }
                    .each_with_object([]) do |msg, acc|
          if acc.last && acc.last[:role] == msg[:role]
            acc.last[:content] = "#{acc.last[:content]}\n#{msg[:content]}"
          else
            acc << msg
          end
        end
      end

      # --- Persistência e auditoria ------------------------------------------

      def persist(role, content)
        @workspace.agent_messages.create!(channel: @channel, role: role, content: content)
      rescue => e
        Rails.logger.error("[Agent::Conversation] falha ao persistir mensagem: #{e.message}")
      end

      def audit_conversation(iterations)
        AuditLog.log(
          action: "ai", origin: "ai", workspace: @workspace, provider: "agent",
          reason: "Conversa do agente (#{@channel})",
          metadata: { iterations: iterations, tools_used: @tools_used.uniq, channel: @channel }
        )
      end

      def provider = Aionis::Integrations.ai

      def text_of(content)
        Array(content).select { |b| b["type"] == "text" }.map { |b| b["text"] }.join("\n").strip
      end

      def reply(text, success:, iterations: 0)
        Reply.new(text: text, success: success, iterations: iterations, tools_used: @tools_used.uniq)
      end
    end
  end
end
