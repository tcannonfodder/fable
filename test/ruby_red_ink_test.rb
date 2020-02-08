require "test_helper"

class RubyRedInkTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::RubyRedInk::VERSION
  end

  def test_it_does_something_useful
    assert false
  end

  def test_loads_json
    refute_empty load_json_export
  end
end
