require_relative "test_helper"

# tests ported from the main Ink API
class OriginalSpecTest < Minitest::Test
  def test_arithmetic
    json = load_json_export("test/fixtures/arithmetic.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "36", story.engine.step
    assert_equal "\n", story.engine.step
    assert_equal "2", story.engine.step
    assert_equal "\n", story.engine.step
    assert_equal "3", story.engine.step
    assert_equal "\n", story.engine.step
    assert_equal "2", story.engine.step
    assert_equal "\n", story.engine.step
    assert_equal "2.333333", story.engine.step
    assert_equal "\n", story.engine.step
    assert_equal "8", story.engine.step
    assert_equal "\n", story.engine.step
    assert_equal "8", story.engine.step
    assert_equal "\n", story.engine.step
  end
end