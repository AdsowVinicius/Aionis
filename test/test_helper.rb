ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Thread parallelization causa race conditions no carregamento de atributos AR
    # (a suíte cruzou o antigo threshold de 500 testes e o deadlock apareceu).
    # Execução serial explícita: rápida o bastante (~20s) e determinística.
    parallelize(workers: 1)

    # Fixtures não carregadas por padrão — tests usam setup com dados inline.
    # Para usar fixtures num test específico: declare `fixtures :nome_da_tabela` na classe.
    self.fixture_paths = []

    # Add more helper methods to be used by all tests here...
  end
end
