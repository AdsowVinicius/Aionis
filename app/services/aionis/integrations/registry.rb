# frozen_string_literal: true

require "erb"
require "yaml"

module Aionis
  module Integrations
    # Registro/fábrica de provedores. É o ponto de injeção de dependência:
    # resolve qual classe concreta atende cada tipo de integração a partir da
    # configuração (config/aionis/integrations.yml + ENV) e memoiza a instância.
    #
    # Permite override em tempo de execução (testes/feature flags) sem que os
    # consumidores saibam da troca:
    #   registry.override(:ocr, FakeOcr.new)
    #   registry.resolve(:ocr) # => FakeOcr
    #   registry.reset!
    class Registry
      # Provedores embutidos (sempre disponíveis). A config pode adicionar
      # outros por tipo; o provedor ativo é escolhido por `provider:`.
      DEFAULT_PROVIDERS = {
        whatsapp:     {
          "null"    => "Aionis::Integrations::Whatsapp::NullProvider",
          # Envio dry-run (dev/test): não chama a Meta, só loga. Resolvido pelo
          # SendMessageJob quando Aionis::Integrations.whatsapp_dry_run? é true.
          "dry_run" => "Aionis::Integrations::Whatsapp::DryRunProvider"
        },
        open_finance: { "null" => "Aionis::Integrations::OpenFinance::NullProvider" },
        ocr:          { "null" => "Aionis::Integrations::Ocr::NullProvider" },
        ai:           { "null" => "Aionis::Integrations::Ai::NullProvider" }
      }.freeze

      def self.default_path
        Rails.root.join("config", "aionis", "integrations.yml")
      end

      # Constrói a partir do arquivo de config (ou de defaults se ausente).
      def self.from_config(env: Rails.env, path: default_path)
        new(load_config(path, env))
      end

      def self.load_config(path, env)
        return {} unless File.exist?(path)

        rendered = ERB.new(File.read(path)).result
        parsed   = YAML.safe_load(rendered, aliases: true) || {}
        parsed[env.to_s] || parsed["default"] || {}
      end

      # config: { "ocr" => { "provider" => "null", "providers" => {..}, "settings" => {..} }, ... }
      def initialize(config = {})
        @config    = config || {}
        @instances = {}
        @overrides = {}
      end

      # Resolve a instância do provedor para o tipo (memoizada). `key` permite
      # escolher um provedor específico (ex.: por canal: "meta_cloud"/"evolution")
      # em vez do provedor padrão da config. Overrides têm precedência (testes).
      def resolve(type, key: nil)
        type = normalize_type(type)
        return @overrides[type] if @overrides.key?(type)

        @instances[[type, key]] ||= build(type, key: key)
      end

      # Injeta um provedor específico (tem precedência sobre a config).
      def override(type, provider)
        @overrides[normalize_type(type)] = provider
        self
      end

      def clear_override(type)
        type = normalize_type(type)
        @overrides.delete(type)
        @instances.delete_if { |(t, _key), _v| t == type }
        self
      end

      def reset!
        @overrides.clear
        @instances.clear
        self
      end

      def configured?(type)
        resolve(type).configured?
      end

      # Chave do provedor ativo para o tipo ("null", "meta_cloud"...).
      def active_provider_key(type)
        type_config(normalize_type(type)).fetch("provider", "null").to_s
      end

      private

      def normalize_type(type)
        sym = type.to_sym
        unless Aionis::Integrations::TYPES.include?(sym)
          raise Errors::UnknownIntegrationType,
                "Tipo de integração desconhecido: #{type.inspect}. Válidos: #{Aionis::Integrations::TYPES.join(', ')}"
        end
        sym
      end

      def type_config(type)
        @config[type.to_s] || @config[type] || {}
      end

      def build(type, key: nil)
        cfg       = type_config(type)
        providers = DEFAULT_PROVIDERS.fetch(type).merge(cfg["providers"] || {})
        chosen    = (key.presence || cfg.fetch("provider", "null")).to_s

        class_name = providers[chosen]
        unless class_name
          raise Errors::UnknownProvider,
                "Provedor '#{chosen}' não mapeado para #{type}. Disponíveis: #{providers.keys.join(', ')}"
        end

        instantiate(class_name, cfg["settings"] || {})
      end

      def instantiate(class_name, settings)
        class_name.constantize.new(settings)
      rescue NameError => e
        raise Errors::ProviderNotLoadable,
              "Não foi possível carregar o provedor #{class_name}: #{e.message}"
      end
    end
  end
end
