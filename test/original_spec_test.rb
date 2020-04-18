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

    assert_equal "Hello world\n", story.continue_maximially + "\n"
  end

  def test_blanks_in_inline_sequences
    json = load_json_export("test/fixtures/original-specs/blanks-in-inline-sequences.ink.json")
    story = RubyRedInk::Story.new(json)

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

    assert_equal result, story.continue_maximially + "\n"
  end

  def test_all_sequence_types
    json = load_json_export("test/fixtures/original-specs/test-all-sequence-types.ink.json")
    story = RubyRedInk::Story.new(json)

    # Switched the order of "shuffle once" because it's still got the job done,
    # just at a different order
    result = <<~STORY
    Once: one two
    Stopping: one two two two
    Default: one two two two
    Cycle: one two one two
    Shuffle: two one one two
    Shuffle stopping: one two final final
    Shuffle once: one two
    STORY

    assert_equal result, story.continue_maximially + "\n"
  end

  def test_call_stack_evaluation
    json = load_json_export("test/fixtures/original-specs/test-call-stack-evaluation.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "8\n", story.continue_maximially + "\n"
  end

  def test_choice_count
    json = load_json_export("test/fixtures/original-specs/choice-count.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "2\n", story.continue_maximially + "\n"
  end

  def test_choice_diverts_to_done
    json = load_json_export("test/fixtures/original-specs/choice-diverts-to-done.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "", story.continue

    assert_equal 1, story.current_choices.size

    picked = story.choose_choice_index(0)

    assert_equal "choice", story.continue
    assert !story.has_errors?
  end

  def test_choice_with_brackets_only
    json = load_json_export("test/fixtures/original-specs/choice-with-brackets-only.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "", story.continue
    assert_equal 1, story.current_choices.size

    assert_equal "Option", story.current_choices[0].text

    story.choose_choice_index(0)

    assert_equal "Text", story.continue
  end

  def test_compare_divert_targets
    json = load_json_export("test/fixtures/original-specs/compare-divert-targets.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    different knot
    same knot
    same knot
    different knot
    same knot
    same knot
    STORY

    assert_equal result, story.continue_maximially + "\n"
  end

  def test_call_complex_tunnels
    json = load_json_export("test/fixtures/original-specs/complex-tunnels.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    one (1)
    one and a half (1.5)
    two (2)
    three (3)
    STORY

    assert_equal result, story.continue_maximially + "\n"
  end

  def test_conditional_choice_in_weave_1
    json = load_json_export("test/fixtures/original-specs/conditional-choice-in-weave-1.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    start
    gather should be seen
    STORY

    assert_equal result, story.continue_maximially + "\n"

    assert_equal 1, story.current_choices.size

    picked = story.choose_choice_index(0)

    assert_equal "result", story.continue_maximially
    assert_equal 0, story.current_choices.size
  end

  def test_conditional_choice_in_weave_2
    json = load_json_export("test/fixtures/original-specs/conditional-choice-in-weave-2.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    first gather
    STORY

    assert_equal result, story.continue + "\n"

    assert_equal 2, story.current_choices.size

    picked = story.choose_choice_index(0)

    result = <<~STORY
    the main gather
    bottom gather
    STORY

    assert_equal result, story.continue + "\n"
    assert_equal 0, story.current_choices.size
  end

  def test_conditional_choices
    json = load_json_export("test/fixtures/original-specs/test-conditional-choices.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "", story.continue_maximially

    assert_equal 4, story.current_choices.size

    assert_equal "one", story.current_choices[0].text
    assert_equal "two", story.current_choices[1].text
    assert_equal "three", story.current_choices[2].text
    assert_equal "four", story.current_choices[3].text
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

    assert_equal result, story.continue_maximially + "\n"
    assert_equal 0, story.current_choices.size
  end

  def test_const
    json = load_json_export("test/fixtures/original-specs/test-const.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "5", story.continue
    assert_equal 0, story.current_choices.size
  end

  def test_default_choice
    json = load_json_export("test/fixtures/original-specs/test-default-choice.ink.json")
    story = RubyRedInk::Story.new(json)
    story.start_profiling

    assert_equal "", story.continue

    assert_equal 2, story.current_choices.size

    assert_equal "Choice 1", story.current_choices[0].text

    assert_equal "Choice 2", story.current_choices[1].text

    picked = story.choose_choice_index(0)

    assert_equal "After choice", story.continue

    assert_equal 1, story.current_choices.size

    assert_equal "Choice 2", story.current_choices[0].text

    picked = story.choose_choice_index(0)

    assert_equal "After choice\nThis is default.", story.continue_maximially
  end

  def test_default_simple_gather
    json = load_json_export("test/fixtures/original-specs/test-default-simple-gather.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "x", story.continue
  end

  def test_divert_in_conditionals
    json = load_json_export("test/fixtures/original-specs/test-divert-in-conditionals.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "", story.continue_maximially
  end

  def test_divert_to_weave_points
    json = load_json_export("test/fixtures/original-specs/test-divert-to-weave-points.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    gather
    test
    choice content
    gather
    second time round
    STORY

    assert_equal result, story.continue_maximially + "\n"
    assert_equal 0, story.current_choices.size
  end

  def test_else_branches
    json = load_json_export("test/fixtures/original-specs/test-else-branches.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    other
    other
    other
    other
    STORY

    assert_equal result, story.continue_maximially + "\n"
    assert_equal 0, story.current_choices.size
  end

  def test_empty
    json = load_json_export("test/fixtures/original-specs/test-empty.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "", story.continue_maximially
  end

  def test_empty_multiline_conditional_branch
    json = load_json_export("test/fixtures/original-specs/text-empty-multiline-conditional-branch.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "", story.continue_maximially
  end

  def test_all_switch_branches_fail_is_clean
    json = load_json_export("test/fixtures/original-specs/test-all-switch-branches-fail-is-clean.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "", story.continue_maximially
    assert_equal 0, story.state.evaluation_stack.size
  end

  def test_trivial_condition
    json = load_json_export("test/fixtures/original-specs/test-trivial-condition.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "", story.continue_maximially
    assert !story.has_errors?
  end

  def test_empty_sequence_content
    json = load_json_export("test/fixtures/original-specs/test-empty-sequence-content.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    Wait for it....
    Surprise!
    Done.
    STORY

    assert_equal result, story.continue_maximially + "\n"
    assert_equal 0, story.current_choices.size
  end

  def test_end
    json = load_json_export("test/fixtures/original-specs/test-end.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "hello", story.continue_maximially
    assert !story.has_errors?
  end

  def test_end_2
    json = load_json_export("test/fixtures/original-specs/test-end-2.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "hello", story.continue_maximially
    assert !story.has_errors?
  end

  def test_escape_character
    json = load_json_export("test/fixtures/original-specs/test-escape-character.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "this is a '|' character", story.continue_maximially
    assert !story.has_errors?
  end

  def test_external_binding
    json = load_json_export("test/fixtures/original-specs/test-external-binding.ink.json")
    story = RubyRedInk::Story.new(json)

    message = nil

    story.bind_external_function("message") do |argument|
        message = "MESSAGE: #{argument}"
    end

    story.bind_external_function("multiply") do |argument_1, argument_2|
        return argument_1 * argument_2
    end

    story.bind_external_function("times") do |number_of_times, string|
        string * number_of_times
    end

    assert_equal "15", story.continue
    assert_equal "knock knock knock", story.continue
    assert_equal "MESSAGE: hello world", message
  end

  def test_factorial_by_reference
    json = load_json_export("test/fixtures/original-specs/test-factorial-by-reference.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "120", story.continue_maximially
    assert !story.has_errors?
  end

  def test_factorial_recursive
    json = load_json_export("test/fixtures/original-specs/test-factorial-recursive.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "120", story.continue_maximially
    assert !story.has_errors?
  end

  def test_gather_choice_same_line
    json = load_json_export("test/fixtures/original-specs/test-gather-choice-same-line.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "", story.continue
    assert_equal "hello", story.current_choices[0].text

    story.choose_choice_index(0)
    story.continue

    assert_equal "world", story.current_choices[0].text
  end

  def test_has_read_on_choice
    json = load_json_export("test/fixtures/original-specs/test-has-read-on-choice.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "", story.continue
    assert_equal "visible choice", story.current_choices[0].text
  end
end