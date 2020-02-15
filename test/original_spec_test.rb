require_relative "test_helper"

# tests ported from the main Ink API
class OriginalSpecTest < Minitest::Test
  def test_arithmetic
    json = load_json_export("test/fixtures/original-specs/arithmetic.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_nil story.engine.step

    result = <<~STORY
    36
    2
    3
    2
    2.333333
    8
    8
    STORY

    assert_equal result, story.engine.current_text
  end

  def test_basic_string_literals
    json = load_json_export("test/fixtures/original-specs/basic-string-literals.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_nil story.engine.step

    result = <<~STORY
    Hello world 1
    Hello world 2.
    STORY

    assert_equal result, story.engine.current_text
  end

  def test_basic_tunnel
    json = load_json_export("test/fixtures/original-specs/basic-tunnel.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_nil story.engine.step
    assert_equal "Hello world\n", story.engine.current_text
  end

  def test_blanks_in_inline_sequences
    json = load_json_export("test/fixtures/original-specs/blanks-in-inline-sequences.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_nil story.engine.step

    result = <<~STORY
    1. a
    2.
    3. b
    4. b
    ---
    1.
    2. a
    3. a
    ---
    1. a
    2.
    3.
    ---
    1.
    2.
    3.

    STORY
    puts story.engine.current_text
    assert_equal result, story.engine.current_text
  end
end