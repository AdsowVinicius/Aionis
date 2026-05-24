ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Thread parallelization causa race conditions no carregamento de atributos AR
    # quando muitos testes são executados juntos. Threshold alto mantém execução serial.
    parallelize(workers: :number_of_processors, with: :threads, threshold: 500)

    # Fixtures não carregadas por padrão — tests usam setup com dados inline.
    # Para usar fixtures num test específico: declare `fixtures :nome_da_tabela` na classe.
    self.fixture_paths = []

    # Add more helper methods to be used by all tests here...
  end
end
