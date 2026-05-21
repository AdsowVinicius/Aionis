ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors, with: :threads)

    # Fixtures não carregadas por padrão — tests usam setup com dados inline.
    # Para usar fixtures num test específico: declare `fixtures :nome_da_tabela` na classe.
    self.fixture_paths = []

    # Add more helper methods to be used by all tests here...
  end
end
