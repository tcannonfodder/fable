require_relative "test_helper"

# tests ported from the main Ink API
class OriginalSpecTest < Minitest::Test
  def test_paths
    # Different instances should ensure different instances of individual components
    path1 = RubyRedInk::Path.new("hello.1.world")
    path2 = RubyRedInk::Path.new("hello.1.world")

    path3 = RubyRedInk::Path.new(".hello.1.world")
    path4 = RubyRedInk::Path.new(".hello.1.world")

    assert_equal path1, path2
    assert_equal path3, path4

    assert  path1 != path3
  end


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

    assert_equal result, story.continue_maximially
  end

  def test_basic_string_literals
    json = load_json_export("test/fixtures/original-specs/basic-string-literals.ink.json")
    story = RubyRedInk::Story.new(json)
    story.start_profiling

    result = <<~STORY
    Hello world 1
    Hello world 2.
    STORY

    assert_equal result, story.continue_maximially
  end

  def test_basic_tunnel
    json = load_json_export("test/fixtures/original-specs/basic-tunnel.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "Hello world\n", story.continue_maximially
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

    assert_equal result, story.continue_maximially
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

    assert_equal result, story.continue_maximially
  end

  def test_call_stack_evaluation
    json = load_json_export("test/fixtures/original-specs/test-call-stack-evaluation.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "8\n", story.continue_maximially
  end

  def test_choice_count
    json = load_json_export("test/fixtures/original-specs/choice-count.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "2\n", story.continue_maximially
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

    assert_equal "Text\n", story.continue
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

    assert_equal result, story.continue_maximially
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

    assert_equal result, story.continue_maximially
  end

  def test_conditional_choice_in_weave_1
    json = load_json_export("test/fixtures/original-specs/conditional-choice-in-weave-1.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    start
    gather should be seen
    STORY
    story.start_profiling
    assert_equal result, story.continue_maximially

    assert_equal 1, story.current_choices.size
    picked = story.choose_choice_index(0)

    assert_equal "result\n", story.continue_maximially
    assert_equal 0, story.current_choices.size
  end

  def test_conditional_choice_in_weave_2
    json = load_json_export("test/fixtures/original-specs/conditional-choice-in-weave-2.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    first gather
    STORY

    assert_equal result, story.continue

    assert_equal 2, story.current_choices.size

    picked = story.choose_choice_index(0)

    result = <<~STORY
    the main gather
    bottom gather
    STORY

    assert_equal result, story.continue_maximially
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

    assert_equal result, story.continue_maximially
    assert_equal 0, story.current_choices.size
  end

  def test_const
    json = load_json_export("test/fixtures/original-specs/test-const.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "5\n", story.continue
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

    assert_equal "After choice\n", story.continue

    assert_equal 1, story.current_choices.size

    assert_equal "Choice 2", story.current_choices[0].text

    picked = story.choose_choice_index(0)

    assert_equal "After choice\nThis is default.\n", story.continue_maximially
  end

  def test_default_simple_gather
    json = load_json_export("test/fixtures/original-specs/test-default-simple-gather.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "x\n", story.continue
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

    assert_equal result, story.continue_maximially
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

    assert_equal result, story.continue_maximially
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

    assert_equal result, story.continue_maximially
    assert_equal 0, story.current_choices.size
  end

  def test_end
    json = load_json_export("test/fixtures/original-specs/test-end.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "hello\n", story.continue_maximially
    assert !story.has_errors?
  end

  def test_end_2
    json = load_json_export("test/fixtures/original-specs/test-end-2.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "hello\n", story.continue_maximially
    assert !story.has_errors?
  end

  def test_escape_character
    json = load_json_export("test/fixtures/original-specs/test-escape-character.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "this is a '|' character\n", story.continue_maximially
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

    assert_equal "120\n", story.continue_maximially
    assert !story.has_errors?
  end

  def test_factorial_recursive
    json = load_json_export("test/fixtures/original-specs/test-factorial-recursive.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "120\n", story.continue_maximially
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

  def test_hello_world
    json = load_json_export("test/fixtures/original-specs/test-hello-world.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "Hello world\n", story.continue_maximially
  end

  def test_identifiers_can_start_with_numbers
    json = load_json_export("test/fixtures/original-specs/test-identifiers-can-start-with-numbers.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "512x2 = 1024\n512x2p2 = 1026\n", story.continue_maximially
  end

  def test_implicit_inline_glue
    json = load_json_export("test/fixtures/original-specs/test-implicit-inline-glue.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "I have five eggs.\n", story.continue_maximially
  end

  def test_implicit_inline_glue_b
    json = load_json_export("test/fixtures/original-specs/test-implicit-inline-glue-b.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    A
    X
    STORY

    assert_equal result, story.continue_maximially
  end

  def test_implicit_inline_glue_c
    json = load_json_export("test/fixtures/original-specs/test-implicit-inline-glue-c.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    A
    C
    STORY

    assert_equal result, story.continue_maximially
  end

  def test_include
    json = load_json_export("test/fixtures/original-specs/test-include.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    This is include 1.
    This is include 2.
    This is the main file.
    STORY

    assert_equal result, story.continue_maximially
  end

  def test_increment
    json = load_json_export("test/fixtures/original-specs/test-increment.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    6
    5
    STORY

    assert_equal result, story.continue_maximially
  end

  def test_knot_gather
    json = load_json_export("test/fixtures/original-specs/test-knot-gather.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "g\n", story.continue_maximially
  end

  def test_knot_thread_interaction
    json = load_json_export("test/fixtures/original-specs/test-knot-thread-interaction.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    blah blah
    STORY

    assert_equal result, story.continue

    assert_equal 2, story.current_choices.size
    assert_equal "option", story.current_choices[0].text
    assert_equal "wigwag", story.current_choices[1].text

    picked = story.choose_choice_index(1)

    result = <<~STORY
    wigwag
    THE END
    STORY

    assert_equal result, story.continue_maximially
    assert !story.has_errors?
  end

  def test_knot_thread_interaction_2
    json = load_json_export("test/fixtures/original-specs/test-knot-thread-interaction-2.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    I’m in a tunnel
    When should this get printed?
    STORY

    assert_equal result, story.continue_maximially

    assert_equal 1, story.current_choices.size
    assert_equal "I’m an option", story.current_choices[0].text

    picked = story.choose_choice_index(0)

    result = <<~STORY
    I’m an option
    Finishing thread.
    STORY

    assert_equal result, story.continue_maximially
    assert !story.has_errors?
  end

  def test_knot_gather
    json = load_json_export("test/fixtures/original-specs/test-leading-newline-multiline-sequence.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "a line after an empty line\n", story.continue
  end

  def test_logic_in_choices
    json = load_json_export("test/fixtures/original-specs/test-logic-in-choices.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "", story.continue_maximially

    assert_equal 1, story.current_choices.size
    assert_equal "'Hello Joe, your name is Joe.'", story.current_choices[0].text

    picked = story.choose_choice_index(0)

    result = <<~STORY
    'Hello Joe,' I said, knowing full well that his name was Joe.
    STORY

    assert_equal result, story.continue_maximially
    assert !story.has_errors?
  end

  def test_multiple_constant_references
    json = load_json_export("test/fixtures/original-specs/test-multiple-constant-references.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "success\n", story.continue
  end

  def test_multi_thread
    json = load_json_export("test/fixtures/original-specs/test-multi-thread.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    This is place 1.
    This is place 2.
    STORY

    assert_equal result, story.continue_maximially

    picked = story.choose_choice_index(0)

    result = <<~STORY
    choice in place 1
    The end
    STORY

    assert_equal result, story.continue_maximially
    assert !story.has_errors?
  end

  def test_nested_include
    json = load_json_export("test/fixtures/original-specs/test-nested-include.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    The value of a variable in test file 2 is 5.
    This is the main file
    The value when accessed from knot_in_2 is 5.
    STORY

    assert_equal result, story.continue_maximially
  end

  def test_nested_pass_by_reference
    json = load_json_export("test/fixtures/original-specs/test-nested-pass-by-reference.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    5
    625
    STORY

    assert_equal result, story.continue_maximially
  end

  def test_non_text_in_choice_inner_content
    json = load_json_export("test/fixtures/original-specs/test-non-text-in-choice-inner-content.ink.json")
    story = RubyRedInk::Story.new(json)

    story.continue

    story.choose_choice_index(0)

    assert_equal "option text. Conditional bit. Next.\n", story.continue
  end

  def test_once_only_choices_can_link_back_to_self
    json = load_json_export("test/fixtures/original-specs/test-once-only-choices-can-link-back-to-self.ink.json")
    story = RubyRedInk::Story.new(json)

    story.continue_maximially

    assert_equal 1, story.current_choices.size
    assert_equal "First choice", story.current_choices[0].text

    story.choose_choice_index(0)
    story.continue_maximially

    assert_equal 1, story.current_choices.size
    assert_equal "Second choice", story.current_choices[0].text

    story.choose_choice_index(0)
    story.continue_maximially

    assert_nil story.current_errors
  end

  def test_once_only_choices_content_with_own_content
    json = load_json_export("test/fixtures/original-specs/test-once-only-choices-with-own-content.ink.json")
    story = RubyRedInk::Story.new(json)

    story.continue_maximially

    assert_equal 3, story.current_choices.size

    story.choose_choice_index(0)
    story.continue_maximially

    assert_equal 2, story.current_choices.size

    story.choose_choice_index(0)
    story.continue_maximially

    assert_equal 1, story.current_choices.size

    story.choose_choice_index(0)
    story.continue_maximially

    assert_equal 0, story.current_choices.size
  end

  def test_path_to_self
    json = load_json_export("test/fixtures/original-specs/test-path-to-self.ink.json")
    story = RubyRedInk::Story.new(json)

    story.continue
    story.choose_choice_index(0)
    story.continue
    story.choose_choice_index(0)
  end

  def test_print_num
    json = load_json_export("test/fixtures/original-specs/test-print-num.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    . four .
    . fifteen .
    . thirty-seven .
    . one hundred and one .
    . two hundred and twenty-two .
    . one thousand two hundred and thirty-four .
    STORY

    assert_equal result, story.continue_maximially
  end

  def test_quote_character_significance
    json = load_json_export("test/fixtures/original-specs/test-quote-character-significance.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "My name is \"Joe\"\n", story.continue_maximially
  end

  def test_read_count_across_callstack
    json = load_json_export("test/fixtures/original-specs/test-read-count-across-callstack.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    1) Seen first 1 times.
    In second.
    2) Seen first 1 times.
    STORY

    assert_equal result, story.continue_maximially
  end

  def test_read_count_across_threads
    json = load_json_export("test/fixtures/original-specs/test-read-count-across-threads.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    1
    1
    STORY

    assert_equal result, story.continue_maximially
  end

  def test_read_count_dot_separated_path
    json = load_json_export("test/fixtures/original-specs/test-read-count-dot-separated-path.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    hi
    hi
    hi
    3
    STORY

    assert_equal result, story.continue_maximially
  end

  def test_same_line_divert_is_newline
    json = load_json_export("test/fixtures/original-specs/test-same-line-divert-is-inline.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    We hurried home to Savile Row as fast as we could.
    STORY

    assert_equal result, story.continue_maximially
  end

  def test_shouldnt_gather_due_to_choice
    json = load_json_export("test/fixtures/original-specs/test-shouldnt-gather-due-to-choice.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "", story.continue_maximially
    story.choose_choice_index(0)

    result = <<~STORY
    opt
    text
    STORY

    assert_equal result, story.continue_maximially
  end

  def test_shuffle_stack_muddying
    json = load_json_export("test/fixtures/original-specs/shuffle-stack-muddying.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "", story.continue

    assert_equal 2, story.current_choices.size
  end

  def test_simple_glue
    json = load_json_export("test/fixtures/original-specs/test-simple-glue.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "Some content with glue.\n", story.continue_maximially
  end

  def test_sticky_choices_stay_sticky
    json = load_json_export("test/fixtures/original-specs/test-sticky-choices-stay-sticky.ink.json")
    story = RubyRedInk::Story.new(json)

    story.continue_maximially
    assert_equal 2, story.current_choices.size

    story.choose_choice_index(0)
    story.continue_maximially
    assert_equal 2, story.current_choices.size
  end
end