require_relative "test_helper"

# tests ported from the main Ink API
class OriginalSpecTest < Minitest::Test
  # include PrettyDiffs
  # Minitest::Test.make_my_diffs_pretty!
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

    assert_equal result, story.engine.current_text + "\n"
  end

  def test_basic_string_literals
    json = load_json_export("test/fixtures/original-specs/basic-string-literals.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_nil story.engine.step

    result = <<~STORY
    Hello world 1
    Hello world 2.
    STORY

    assert_equal result, story.engine.current_text + "\n"
  end

  def test_basic_tunnel
    json = load_json_export("test/fixtures/original-specs/basic-tunnel.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_nil story.engine.step
    assert_equal "Hello world\n", story.engine.current_text + "\n"
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

    assert_equal result, story.engine.current_text + "\n"
  end

  def test_all_sequence_types
    json = load_json_export("test/fixtures/original-specs/test-all-sequence-types.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_nil story.engine.step

    # Switched the order of "shuffle once" because it's still got the job done,
    # just at a different order
    result = <<~STORY
    Once: one two  
    Stopping: one two two two
    Default: one two two two
    Cycle: one two one two
    Shuffle: two one two one
    Shuffle stopping: one two final final
    Shuffle once: one two
    STORY

    assert_equal result, story.engine.current_text + "\n"
  end

  def test_call_stack_evaluation
    json = load_json_export("test/fixtures/original-specs/test-call-stack-evaluation.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_nil story.engine.step

    assert_equal "8\n", story.engine.current_text + "\n"
  end

  def test_choice_count
    json = load_json_export("test/fixtures/original-specs/choice-count.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_nil story.engine.step

    assert_equal "2\n", story.engine.current_text + "\n"
  end
end