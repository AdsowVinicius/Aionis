# frozen_string_literal: true

module Aionis
  module Integrations
    # Valor de retorno unificado de qualquer provedor de integração.
    # Mantém a interface estável entre provedores diferentes: o app consumidor
    # sempre inspeciona os mesmos campos, independentemente de quem respondeu.
    #
    #   result.success?      # chamada concluída com dados
    #   result.unavailable?  # provedor não configurado / sem chamada externa
    #   result.data          # payload normalizado (Hash)
    #   result.message       # texto explicativo (erros, avisos)
    #   result.provider      # chave do provedor que respondeu ("null", "meta_cloud"...)
    class Result
      STATUSES = %i[ok error unavailable pending].freeze

      attr_reader :provider, :status, :data, :message

      def initialize(success:, provider:, status: :ok, data: {}, message: nil)
        @success  = success
        @provider = provider.to_s
        @status   = status.to_sym
        @data     = (data || {}).freeze
        @message  = message
        freeze
      end

      def success?     = @success
      def failure?     = !@success
      def unavailable? = status == :unavailable
      def pending?     = status == :pending

      def to_h
        { success: success?, provider: provider, status: status, data: data, message: message }
      end

      # Fábricas de conveniência usadas pelos provedores
      def self.ok(provider:, data: {}, message: nil)
        new(success: true, provider: provider, status: :ok, data: data, message: message)
      end

      def self.error(provider:, message:, data: {})
        new(success: false, provider: provider, status: :error, data: data, message: message)
      end

      def self.unavailable(provider:, message:)
        new(success: false, provider: provider, status: :unavailable, message: message)
      end

      def self.pending(provider:, message: nil, data: {})
        new(success: false, provider: provider, status: :pending, data: data, message: message)
      end
    end
  end
end
