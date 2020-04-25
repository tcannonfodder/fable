require_relative "test_helper"

class FableTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Fable::VERSION
  end
end
