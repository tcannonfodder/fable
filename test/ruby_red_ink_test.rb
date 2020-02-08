require_relative "test_helper"

class RubyRedInkTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::RubyRedInk::VERSION
  end
end
