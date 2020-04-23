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
    2.3333333
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

  def test_string_constants
    json = load_json_export("test/fixtures/original-specs/test-string-constants.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "hi\n", story.continue_maximially
  end

  def test_strings_in_choices
    json = load_json_export("test/fixtures/original-specs/test-strings-in-choices.ink.json")
    story = RubyRedInk::Story.new(json)

    story.continue_maximially
    assert_equal 1, story.current_choices.size
    assert_equal "test1 \"test2 test3\"", story.current_choices[0].text

    story.choose_choice_index(0)
    assert_equal "test1 test4\n", story.continue
  end

  def test_string_type_coercion
    json = load_json_export("test/fixtures/original-specs/test-string-type-coercion.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    same
    different
    STORY

    assert_equal result, story.continue_maximially
  end

  def test_temporaries_at_global_scope
    json = load_json_export("test/fixtures/original-specs/test-temporaries-at-global-scope.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    54
    STORY

    assert_equal result, story.continue_maximially
  end

  def test_thread_done
    json = load_json_export("test/fixtures/original-specs/test-thread-done.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    This is a thread example
    Hello.
    The example is now complete.
    STORY

    assert_equal result, story.continue_maximially
  end

  def test_tunnel_onwards_after_tunnel
    json = load_json_export("test/fixtures/original-specs/test-tunnel-onwards-after-tunnel.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    Hello...
    ...world.
    The End.
    STORY

    assert_equal result, story.continue_maximially
  end

  def test_tunnel_vs_thread_behavior
    json = load_json_export("test/fixtures/original-specs/test-tunnel-vs-thread-behavior.ink.json")
    story = RubyRedInk::Story.new(json)

    assert !story.continue_maximially.include?("Finished tunnel")

    assert_equal 2, story.current_choices.size

    story.choose_choice_index(0)

    assert_match "Finished tunnel", story.continue_maximially
    assert_equal 3, story.current_choices.size

    story.choose_choice_index(2)

    assert_match "Done.", story.continue_maximially
  end

  def test_turns_since
    json = load_json_export("test/fixtures/original-specs/test-turns-since.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    -1
    0
    STORY

    assert_equal result, story.continue_maximially

    story.choose_choice_index(0)

    assert_equal "1\n", story.continue_maximially

    story.choose_choice_index(0)

    assert_equal "2\n", story.continue_maximially
  end

  def test_turns_since_nested
    json = load_json_export("test/fixtures/original-specs/test-turns-since-nested.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    -1 = -1
    STORY

    assert_equal result, story.continue_maximially

    assert_equal 1, story.current_choices.size
    story.choose_choice_index(0)

    result = <<~STORY
    stuff
    0 = 0
    STORY

    assert_equal result, story.continue_maximially

    assert_equal 1, story.current_choices.size
    story.choose_choice_index(0)

    result = <<~STORY
    more stuff
    1 = 1
    STORY

    assert_equal result, story.continue_maximially
  end

  def test_turns_since_with_variable_target
    json = load_json_export("test/fixtures/original-specs/test-turns-since-with-variable-target.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    0
    0
    STORY

    assert_equal result, story.continue_maximially

    story.choose_choice_index(0)

    assert_equal "1\n", story.continue_maximially
  end

  def test_unbalanced_weave_indentation
    json = load_json_export("test/fixtures/original-specs/test-unbalanced-weave-indentation.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "", story.continue_maximially

    assert_equal 1, story.current_choices.size
    assert_equal "First", story.current_choices[0].text

    story.choose_choice_index(0)

    result = <<~STORY
    First
    STORY

    assert_equal result, story.continue_maximially

    assert_equal 1, story.current_choices.size
    story.choose_choice_index(0)

    result = <<~STORY
    Very indented
    End
    STORY

    assert_equal result, story.continue_maximially

    assert_equal 0, story.current_choices.size
  end

  def test_variable_declaration_in_conditional
    json = load_json_export("test/fixtures/original-specs/test-variable-declaration-in-conditional.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    5
    STORY

    assert_equal result, story.continue_maximially
  end

  def test_variable_divert_target
    json = load_json_export("test/fixtures/original-specs/test-variable-divert-target.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    Here.
    STORY

    assert_equal result, story.continue_maximially
  end

  def test_variable_get_set_api
    json = load_json_export("test/fixtures/original-specs/test-variable-get-set-api.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "5\n", story.continue_maximially
    assert_equal 5, story.variables_state["x"]

    story.variables_state["x"] = 10

    story.choose_choice_index(0)
    assert_equal "10\n", story.continue_maximially
    assert_equal 10, story.variables_state["x"]

    story.variables_state["x"] = 8.5

    story.choose_choice_index(0)
    assert_equal "8.5\n", story.continue_maximially
    assert_equal 8.5, story.variables_state["x"]

    story.variables_state["x"] = "a string"

    story.choose_choice_index(0)
    assert_equal "a string\n", story.continue_maximially
    assert_equal "a string", story.variables_state["x"]

    assert_nil story.variables_state["z"]

    assert_raises RubyRedInk::StoryError do
      story.variables_state["x"] = Set.new
    end
  end

  def test_variable_observer
    json = load_json_export("test/fixtures/original-specs/test-variable-observer.ink.json")
    story = RubyRedInk::Story.new(json)

    current_variable_value = 0
    observer_call_count = 0

    story.observe_variable("testVar") do |variable_name, new_value|
      current_variable_value = new_value
      observer_call_count += 1
    end

    story.continue_maximially

    assert_equal 15, current_variable_value
    assert_equal 1, observer_call_count
    assert_equal 1, story.current_choices.size

    story.choose_choice_index(0)
    story.continue

    assert_equal 25, current_variable_value
    assert_equal 2, observer_call_count
  end

  def test_variable_pointer_reference_from_knot
    json = load_json_export("test/fixtures/original-specs/test-variable-pointer-reference-from-knot.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "6\n", story.continue
  end

  def test_variable_swap_recursive
    json = load_json_export("test/fixtures/original-specs/test-variable-swap-recursive.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "1 2\n", story.continue
  end

  def test_variable_tunnel
    json = load_json_export("test/fixtures/original-specs/test-variable-tunnel.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "STUFF\n", story.continue_maximially
  end

  def test_weave_gathers
    json = load_json_export("test/fixtures/original-specs/test-weave-gathers.ink.json")
    story = RubyRedInk::Story.new(json)

    story.continue_maximially

    assert_equal 2, story.current_choices.size
    assert_equal "one", story.current_choices[0].text
    assert_equal "four", story.current_choices[1].text

    story.choose_choice_index(0)
    story.continue_maximially

    assert_equal 1, story.current_choices.size
    assert_equal "two", story.current_choices[0].text

    story.choose_choice_index(0)

    result = <<~STORY
    two
    three
    six
    STORY

    assert_equal result, story.continue_maximially
  end

  def test_weave_options
    json = load_json_export("test/fixtures/original-specs/test-weave-options.ink.json")
    story = RubyRedInk::Story.new(json)

    story.continue

    assert_equal "Hello.", story.current_choices[0].text

    story.choose_choice_index(0)

    assert_equal "Hello, world.\n", story.continue_maximially
  end

  def test_whitespace
    json = load_json_export("test/fixtures/original-specs/test-whitespace.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    Hello!
    World.
    STORY

    assert_equal result, story.continue_maximially
  end

  def test_visit_counts_when_choosing
    json = load_json_export("test/fixtures/original-specs/test-visit-counts-when-choosing.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal 0, story.state.visit_count_at_path_string("TestKnot")
    assert_equal 0, story.state.visit_count_at_path_string("TestKnot2")

    story.choose_path_string("TestKnot")

    assert_equal 1, story.state.visit_count_at_path_string("TestKnot")
    assert_equal 0, story.state.visit_count_at_path_string("TestKnot2")

    story.continue

    assert_equal 1, story.state.visit_count_at_path_string("TestKnot")
    assert_equal 0, story.state.visit_count_at_path_string("TestKnot2")

    story.choose_choice_index(0)

    assert_equal 1, story.state.visit_count_at_path_string("TestKnot")
    assert_equal 0, story.state.visit_count_at_path_string("TestKnot2")

    story.continue

    assert_equal 1, story.state.visit_count_at_path_string("TestKnot")
    assert_equal 1, story.state.visit_count_at_path_string("TestKnot2")
  end

  def test_visit_count_bug_due_to_nested_containers
    json = load_json_export("test/fixtures/original-specs/text-visit-count-bug-due-to-nested-containers.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "1\n", story.continue

    story.choose_choice_index(0)

    result = <<~STORY
    choice
    1
    STORY

    assert_equal result, story.continue_maximially
  end

  def test_temp_global_conflict
    json = load_json_export("test/fixtures/original-specs/test-temp-global-conflict.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "0\n", story.continue
  end

  def test_thread_in_logic
    json = load_json_export("test/fixtures/original-specs/test-thread-in-logic.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "Content\n", story.continue
  end

  def test_temp_usage_in_options
    json = load_json_export("test/fixtures/original-specs/test-temp-usage-in-options.ink.json")
    story = RubyRedInk::Story.new(json)

    story.continue
    assert_equal 1, story.current_choices.size
    assert_equal "1", story.current_choices[0].text
    story.choose_choice_index(0)

    result = <<~STORY
    1
    End of choice
    this another
    STORY

    assert_equal result, story.continue_maximially
    assert_equal 0, story.current_choices.size
  end

  def test_evaluating_ink_function_from_game
    json = load_json_export("test/fixtures/original-specs/test-evaluating-ink-function-from-game.ink.json")
    story = RubyRedInk::Story.new(json)

    story.continue

    returned_divert_target = story.evaluate_function("test")
    assert_equal "somewhere.here", returned_divert_target
  end

  def test_evaluating_ink_function_from_game_2
    json = load_json_export("test/fixtures/original-specs/test-evaluating-ink-function-from-game-2.ink.json")
    story = RubyRedInk::Story.new(json)

    results = story.evaluate_function("func1", return_text_output: true)

    assert_equal "This is a function\n", results[:text_output]
    assert_equal 5, results[:return_value]

    assert_equal "One\n", story.continue

    results = story.evaluate_function("func2", return_text_output: true)

    assert_equal "This is a function without a return value\n", results[:text_output]
    assert_nil results[:return_value]

    assert_equal "Two\n", story.continue

    results = story.evaluate_function("add", 1, 2, return_text_output: true)

    assert_equal "x = 1, y = 2\n", results[:text_output]
    assert_equal 3, results[:return_value]

    assert_equal "Three\n", story.continue
  end

  def test_evaluating_function_variable_state_bug
    json = load_json_export("test/fixtures/original-specs/test-evaluating-function-variable-state-bug.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "Start\n", story.continue
    assert_equal "In tunnel.\n", story.continue

    result = story.evaluate_function("func1")
    assert_equal "RIGHT", result

    assert_equal "End\n", story.continue
  end

  def test_done_stops_thread
    json = load_json_export("test/fixtures/original-specs/test-done-stops-thread.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_equal "", story.continue_maximially
  end

  def test_right_left_glue_matching
    json = load_json_export("test/fixtures/original-specs/test-right-left-glue-matching.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    A line.
    Another line.
    STORY

    assert_equal result, story.continue_maximially
  end

  def test_set_nonexistent_variable
    json = load_json_export("test/fixtures/original-specs/test-set-nonexistent-variable.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    Hello world.
    STORY

    assert_equal result, story.continue_maximially

    assert_raises RubyRedInk::StoryError do
      story.variables_state["y"] = "earth"
    end
  end

  def test_tags
    json = load_json_export("test/fixtures/original-specs/test-tags.ink.json")
    story = RubyRedInk::Story.new(json)

    global_tags = ["author: Joe", "title: My Great Story"]
    knot_tags = ["knot tag"]
    knot_tag_when_continued_twice = ["end of knot tag"]
    stitch_tags = ["stitch tag"]

    assert_equal global_tags, story.global_tags

    result = <<~STORY
    This is the content
    STORY

    assert_equal result, story.continue
    assert_equal global_tags, story.current_tags

    assert_equal knot_tags, story.tags_for_content_at_path("knot")
    assert_equal stitch_tags, story.tags_for_content_at_path("knot.stitch")

    story.choose_path_string("knot")

    result = <<~STORY
    Knot content
    STORY

    assert_equal result, story.continue
    assert_equal knot_tags, story.current_tags
    assert_equal "", story.continue
    assert_equal knot_tag_when_continued_twice, story.current_tags
  end

  def test_tunnel_onwards_divert_override
    json = load_json_export("test/fixtures/original-specs/test-tunnel-onwards-divert-override.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    This is A
    Now in B.
    STORY

    assert_equal result, story.continue_maximially
  end

  def test_list_basic_operations
    json = load_json_export("test/fixtures/original-specs/test-list-basic-operations.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    b, d
    a, b, c, e
    b, c
    0
    1
    1
    STORY

    assert_equal result, story.continue_maximially
  end

  def test_more_list_operations
    json = load_json_export("test/fixtures/original-specs/test-more-list-operations.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    1
    l
    n
    l, m
    n
    STORY

    assert_equal result, story.continue_maximially
  end

  def test_empty_list_origin
    json = load_json_export("test/fixtures/original-specs/test-list-empty-origin.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    a, b
    STORY

    assert_equal result, story.continue_maximially
  end

  def test_empty_list_origin_after_assignment
    json = load_json_export("test/fixtures/original-specs/test-empty-list-origin-after-assignment.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    a, b, c
    STORY

    assert_equal result, story.continue_maximially
  end

  def test_list_save_load
    json = load_json_export("test/fixtures/original-specs/test-list-save-load.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    a, x, c
    STORY

    assert_equal result, story.continue_maximially

    saved_state = story.state.to_hash

    story = RubyRedInk::Story.new(json)

    story.state.from_hash!(saved_state)

    story.choose_path_string("elsewhere")

    assert_equal "a, x, c, z\n", story.continue_maximially
  end

  def test_author_warning_inside_content_list_bug
    json = load_json_export("test/fixtures/original-specs/test-author-warning-inside-content-list-bug.ink.json")
    story = RubyRedInk::Story.new(json)
    assert !story.has_errors?
  end

  def test_weave_within_sequence
    json = load_json_export("test/fixtures/original-specs/test-weave-within-sequence.ink.json")
    story = RubyRedInk::Story.new(json)

    story.continue
    assert_equal 1, story.current_choices.size

    story.choose_choice_index(0)

    result = <<~STORY
    choice
    nextline
    STORY

    assert_equal result, story.continue_maximially
  end

  def test_tunnel_onwards_divert_after_with_arg
    json = load_json_export("test/fixtures/original-specs/test-tunnel-onwards-divert-after-with-arg.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    8
    STORY

    assert_equal result, story.continue_maximially
  end

  def test_various_default_choices
    json = load_json_export("test/fixtures/original-specs/test-various-default-choices.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    1
    2
    3
    STORY

    assert_equal result, story.continue_maximially
  end

  def test_tunnel_onwards_with_parameter_default_choice
    json = load_json_export("test/fixtures/original-specs/test-tunnel-onwards-with-parameter-default-choice.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    8
    STORY

    assert_equal result, story.continue_maximially
  end

   def test_read_count_variable_target
    json = load_json_export("test/fixtures/original-specs/test-read-count-variable-target.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    Count start: 0 0 0
    1
    2
    3
    Count end: 3 3 3
    STORY

    assert_equal result, story.continue_maximially
  end

  def test_divert_targets_with_parameters
    json = load_json_export("test/fixtures/original-specs/test-divert-targets-with-parameters.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    5
    STORY

    assert_equal result, story.continue_maximially
  end

  def test_tag_on_choice
    json = load_json_export("test/fixtures/original-specs/test-tag-on-choice.ink.json")
    story = RubyRedInk::Story.new(json)

    story.continue

    story.choose_choice_index(0)


    assert_equal "Hello", story.continue
    assert_equal ["hey"], story.current_tags

    result = <<~STORY
    5
    STORY

    assert_equal result, story.continue_maximially
  end

  def test_string_contains
    json = load_json_export("test/fixtures/original-specs/test-string-contains.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    1
    0
    1
    1
    STORY

    assert_equal result, story.continue_maximially
  end

  def test_evaluation_stack_leaks
    json = load_json_export("test/fixtures/original-specs/test-evaluation-stack-leaks.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    else
    else
    hi
    STORY

    assert_equal result, story.continue_maximially
    assert_equal 0, story.state.evaluation_stack.size
  end


  def test_ink_game_back_and_forth
    json = load_json_export("test/fixtures/original-specs/test-game-ink-back-and-forth.ink.json")
    story = RubyRedInk::Story.new(json)

    # Crazy game/ink callstack:
    # - Game calls "topExternal(5)" (Game -> ink)
    # - topExternal calls gameInc(5) (ink -> Game)
    # - gameInk increments to 6
    # - gameInk calls inkInc(6) (Game -> ink)
    # - inkInc just increments to 7 (ink)
    # And the whole thing unwinds again back to game.

    story.bind_external_function("gameInc") do |x|
      x += 1
      x = story.evaluate_function("inkInc", x)
      return x
    end

    final_result = story.evaluate_function("topExternal", 5, return_text_output: true)

    assert_equal 7, final_result[:return_value]
    assert_equal "In top external\n", final_result[:text_output]
  end

  def test_newlines_with_string_eval
    json = load_json_export("test/fixtures/original-specs/test-newlines-with-string-eval.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    A
    B
    A
    3
    B
    STORY

    assert_equal result, story.continue_maximially
  end

  def test_newlines_trimming_with_functional_external_callback
    json = load_json_export("test/fixtures/original-specs/test-newlines-trimming-with-functional-external-fallback.ink.json")
    story = RubyRedInk::Story.new(json)

    story.allow_external_function_fallbacks = true

    result = <<~STORY
    Phrase 1
    Phrase 2
    STORY

    assert_equal result, story.continue_maximially
  end

  def test_multiline_logic_with_glue
    json = load_json_export("test/fixtures/original-specs/test-multiline-logic-with-glue.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    a b
    a b
    STORY

    assert_equal result, story.continue_maximially
  end

  def test_newline_at_start_of_multiline_conditional
    json = load_json_export("test/fixtures/original-specs/text-newline-at-start-of-multiline-conditional.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    X
    x
    STORY

    assert_equal result, story.continue_maximially
  end

  def test_temp_not_found
    json = load_json_export("test/fixtures/original-specs/test-temp-not-found.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    0
    hello
    STORY

    assert_equal result, story.continue_maximially
    assert story.has_warnings?
  end

  def test_top_flow_terminator_shouldnt_kill_thread_choices
    json = load_json_export("test/fixtures/original-specs/test-top-flow-terminator-shouldnt-kill-thread-choices.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    Limes
    STORY

    assert_equal result, story.continue_maximially
    assert_equal 1, story.current_choices.size
  end

  def test_newline_consistency
    json = load_json_export("test/fixtures/original-specs/test-newline-consistency-1.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    hello world
    STORY

    assert_equal result, story.continue_maximially


    json = load_json_export("test/fixtures/original-specs/test-newline-consistency-2.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    hello world
    STORY

    story.continue
    story.choose_choice_index(0)
    assert_equal result, story.continue_maximially

    json = load_json_export("test/fixtures/original-specs/test-newline-consistency-3.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    hello
    world
    STORY

    story.continue
    story.choose_choice_index(0)
    assert_equal result, story.continue_maximially
  end

  def test_list_random
    json = load_json_export("test/fixtures/original-specs/test-list-random.ink.json")
    story = RubyRedInk::Story.new(json)

    while story.can_continue?
      assert_includes ["B\n", "C\n", "D\n"], story.continue
    end
  end

  def test_turns
    json = load_json_export("test/fixtures/original-specs/test-turns.ink.json")
    story = RubyRedInk::Story.new(json)

    10.times do |n|
      assert_equal "#{n}\n", story.continue
      story.choose_choice_index(0)
    end
  end

  def test_logic_lines_with_newlines
    json = load_json_export("test/fixtures/original-specs/test-logic-lines-with-newlines.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    text1
    text 2
    text1
    text 2
    STORY

    assert_equal result, story.continue_maximially
  end


  def test_floor_ceiling_and_casts
    json = load_json_export("test/fixtures/original-specs/test-floor-ceiling-and-casts.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    1
    1
    2
    0.6666667
    0
    1
    STORY

    assert_equal result, story.continue_maximially
  end

  def test_list_range
    json = load_json_export("test/fixtures/original-specs/test-list-range.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    Pound, Pizza, Euro, Pasta, Dollar, Curry, Paella
    Euro, Pasta, Dollar, Curry
    Two, Three, Four, Five, Six
    Pizza, Pasta
    STORY

    assert_equal result, story.continue_maximially
  end

  def test_knot_stitch_gather_counts
    json = load_json_export("test/fixtures/original-specs/test-knot-stitch-gather-counts.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    1 1
    2 2
    3 3
    1 1
    2 1
    3 1
    1 2
    2 2
    3 2
    1 1
    2 1
    3 1
    1 2
    2 2
    3 2
    STORY

    assert_equal result, story.continue_maximially
  end

  def test_choice_thread_forking
    json = load_json_export("test/fixtures/original-specs/test-choice-thread-forking.ink.json")
    story = RubyRedInk::Story.new(json)

    # generate the choice with the forked thread
    story.continue

    # Save/Reload
    saved_state = story.state.to_hash
    story = RubyRedInk::Story.new(json)
    story.state.from_hash!(saved_state)

    # Load the choice, it should have its own thread still
    # that still has the captured temp x
    story.choose_choice_index(0)
    story.continue_maximially

    # Don't want this warning:
    # RUNTIME WARNING: '' line 7: Variable not found: 'x'
    assert !story.has_warnings?
  end


  def test_fallback_choice_on_thread
    json = load_json_export("test/fixtures/original-specs/test-fallback-choice-on-thread.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    Should be 1 not 0: 1.
    STORY

    assert_equal result, story.continue_maximially
  end

  # Test for bug where after a call to ChoosePathString,
  # the callstack is not fully/cleanly reset, e.g. leaving
  # "inExpressionEvaluation" variable left to true, as set during
  # the call to {RunAThing()}.
  # This was when we unwound the callstack, but we didn't reset
  # the base element.
  def test_clean_callstack_reset_on_path_choice
    json = load_json_export("test/fixtures/original-specs/test-clean-callstack-reset-on-path-choice.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    The first line.
    STORY

    assert_equal result, story.continue

    story.choose_path_string("SomewhereElse")

    result = <<~STORY
    somewhere else
    STORY

    assert_equal result, story.continue
  end

  # Test for bug where choice's owned thread would get 
  # reused between re-runs after a state reset, and in
  # this case would be in the middle of expression evaluation
  # at the time, causing an error.
  # Fixed by re-forking the choice thread
  # in TryFollowDefaultInvisibleChoice
  def test_state_rollback_over_default_choice
    json = load_json_export("test/fixtures/original-specs/test-state-rollback-over-default-choice.ink.json")
    story = RubyRedInk::Story.new(json)

    result = <<~STORY
    Text.
    STORY

    assert_equal result, story.continue


    result = <<~STORY
    5
    STORY

    assert_equal result, story.continue
  end
end