# frozen_string_literal: true

module Aionis
  module Agent
    # Registro das tools disponíveis para o agente. Constrói cada tool com o
    # workspace DA SESSÃO (injeção pelo backend — a LLM nunca escolhe workspace)
    # e executa por nome. Tool desconhecida vira erro amigável no tool_result —
    # nunca exceção, nunca query improvisada.
    class Toolbox
      TOOLS = [
        Tools::ConsultarSaldo,
        Tools::ConsultarGastos,
        Tools::ConsultarTransacoes,
        Tools::ConsultarContas,
        Tools::ConsultarKpis,
        Tools::RegistrarLancamento,
        Tools::GerarInsight,
        Tools::LerMemoria,
        Tools::SalvarMemoria
      ].freeze

      def initialize(workspace, user: nil, channel: nil)
        @workspace = workspace
        @user      = user
        @channel   = channel
      end

      # Definições para o parâmetro tools: da Messages API.
      def definitions = TOOLS.map(&:definition)

      def tool_names = TOOLS.map(&:tool_name)

      # Executa a tool pelo nome com os argumentos DA LLM (o workspace nunca
      # vem deles). Retorna sempre um Hash serializável.
      def execute(name, args)
        klass = TOOLS.find { |t| t.tool_name == name }
        return { "erro" => "Ferramenta desconhecida: #{name}." } unless klass

        klass.new(@workspace, user: @user, channel: @channel).call((args || {}).stringify_keys)
      rescue => e
        Rails.logger.error("[Agent::Toolbox] #{name} falhou: #{e.class}: #{e.message}")
        { "erro" => "Não consegui completar essa consulta agora. Tente novamente." }
      end
    end
  end
end
