ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "mocha/minitest"
require "shoulda/matchers"
require "shoulda/context"

# shoulda-context 2.0.0 monkey-patches Rails::TestUnitReporter#format_rerun_snippet
# with a bare `executable` reference. Rails 8.1 exposes it as a class-level method.
# Re-patch with the correct call so failure output renders cleanly.
require "rails/test_unit/reporter"
Rails::TestUnitReporter.class_eval do
  def format_rerun_snippet(result)
    location, line =
      if result.respond_to?(:source_location)
        result.source_location
      else
        result.method(result.name).source_location
      end
    "#{self.class.executable} #{relative_path_for(location)}:#{line}"
  end
end

Dir[Rails.root.join("test/support/**/*.rb")].each { |f| require f }

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :minitest
    with.library :rails
  end
end

module ActiveSupport
  class TestCase
    parallelize(workers: 1)

    include FactoryBot::Syntax::Methods
  end
end

class ActionDispatch::IntegrationTest
  include AuthenticationHelpers
end
