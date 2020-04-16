require_relative "test_helper"

# tests ported from the main Ink API
class OriginalSpecTest < Minitest::Test
  # include PrettyDiffs
  # Minitest::Test.make_my_diffs_pretty!
  def test_arithmetic
    json = load_json_export("test/fixtures/original-specs/arithmetic.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    36
    2
    3
    2
    2.333333
    8
    8
    STORY

    assert_equal result, story.continue_maximially + "\n"
  end

  def test_basic_string_literals
    json = load_json_export("test/fixtures/original-specs/basic-string-literals.ink.json")
    story = RubyRedInk::Story.new(json)
    story.start_profiling

    result = <<~STORY
    Hello world 1
    Hello world 2.
    STORY

    assert_equal result, story.continue_maximially + "\n"
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

  def test_choice_diverts_to_done
    json = load_json_export("test/fixtures/original-specs/choice-diverts-to-done.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_nil story.engine.step
    assert_equal "", story.engine.current_text

    assert_equal 1, story.engine.current_choices.size

    picked = story.engine.pick_choice(0)

    assert_nil story.engine.step
    assert_equal "choice", story.engine.current_text
  end

  def test_choice_with_brackets_only
    json = load_json_export("test/fixtures/original-specs/choice-with-brackets-only.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_nil story.engine.step
    assert_equal "", story.engine.current_text
    assert_equal 1, story.engine.current_choices.size

    picked = story.engine.pick_choice(0)

    assert_equal "Option", picked.choice_only_content
    assert_nil picked.start_content

    assert_nil story.engine.step
    assert_equal "Text", story.engine.current_text
  end

  def test_call_complex_tunnels
    json = load_json_export("test/fixtures/original-specs/complex-tunnels.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_nil story.engine.step

    puts story.engine.current_text

    result = <<~STORY
    one (1)
    one and a half (1.5)
    two (2)
    three (3)
    STORY

    assert_equal result, story.engine.current_text + "\n"
  end

  def test_conditional_choice_in_weave_1
    json = load_json_export("test/fixtures/original-specs/conditional-choice-in-weave-1.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_nil story.engine.step

    puts story.engine.current_text

    result = <<~STORY
    start
    gather should be seen
    STORY

    assert_equal result, story.engine.current_text + "\n"

    assert_equal 1, story.engine.current_choices.size

    picked = story.engine.pick_choice(0)

    assert_nil story.engine.step
    assert_equal "result", story.engine.current_text
    assert_equal 0, story.engine.current_choices.size
  end

  def test_conditional_choice_in_weave_2
    json = load_json_export("test/fixtures/original-specs/conditional-choice-in-weave-2.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_nil story.engine.step

    puts story.engine.current_text

    result = <<~STORY
    first gather
    STORY

    assert_equal result, story.engine.current_text + "\n"

    assert_equal 2, story.engine.current_choices.size

    picked = story.engine.pick_choice(0)

    result = <<~STORY
    the main gather
    bottom gather
    STORY

    assert_nil story.engine.step
    assert_equal result, story.engine.current_text + "\n"
    assert_equal 0, story.engine.current_choices.size
  end

  def test_conditional_choices
    json = load_json_export("test/fixtures/original-specs/test-conditional-choices.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_nil story.engine.step

    assert story.engine.current_text.empty?

    assert_equal 4, story.engine.current_choices.size

    assert_equal "one", story.engine.current_choices[0].start_content
    assert_nil story.engine.current_choices[0].choice_only_content

    assert_equal "two", story.engine.current_choices[1].start_content
    assert_nil story.engine.current_choices[1].choice_only_content

    assert_equal "three", story.engine.current_choices[2].start_content
    assert_nil story.engine.current_choices[2].choice_only_content

    assert_equal "four", story.engine.current_choices[3].start_content
    assert_nil story.engine.current_choices[3].choice_only_content
  end

  def test_conditionals
    json = load_json_export("test/fixtures/original-specs/test-conditionals.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    true
    true
    true
    true
    true
    great
    right?
    STORY

    assert_nil story.engine.step
    assert_equal result, story.engine.current_text + "\n"

    assert_equal 0, story.engine.current_choices.size
  end

  def test_const
    json = load_json_export("test/fixtures/original-specs/test-const.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_nil story.engine.step
    assert_equal "5", story.engine.current_text

    assert_equal 0, story.engine.current_choices.size
  end

  def test_default_choice
    json = load_json_export("test/fixtures/original-specs/test-default-choice.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_nil story.engine.step

    assert  story.engine.current_text.empty?

    assert_equal 2, story.engine.current_choices.size

    assert_nil story.engine.current_choices[0].start_content
    assert_equal "Choice 1", story.engine.current_choices[0].choice_only_content

    assert_nil story.engine.current_choices[1].start_content
    assert_equal "Choice 2", story.engine.current_choices[1].choice_only_content

    puts "***************************"

    picked = story.engine.pick_choice(0)

    assert_nil story.engine.step

    assert_equal "After choice", story.engine.current_text

    assert_equal 1, story.engine.current_choices.size

    assert_equal "Choice 2", story.engine.current_choices[0].start_content
    assert_nil story.engine.current_choices[0].choice_only_content

    picked = story.engine.pick_choice(0)

    assert_nil story.engine.step
    assert_equal "After choice\nThis is default.", story.engine.current_text
  end
end