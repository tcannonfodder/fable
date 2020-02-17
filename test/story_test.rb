require_relative "test_helper"

class StoryTest < Minitest::Test
  def test_load_hello_world
    json = load_json_export("test/fixtures/hello-world.expanded.ink.json")
    story = RubyRedInk::Story.new(json)
    story.root
    puts "---" * 20

    20.times do
        value = story.engine.step
        next if value.nil?
        puts value
        puts "📌[#{story.engine.current_pointer}]"
    end


    puts "---" * 20
  end

  def test_load_hello_world_choice
    json = load_json_export("test/fixtures/hello-world-choice.expanded.ink.json")
    story = RubyRedInk::Story.new(json)
    story.root
    puts "---" * 20

    20.times do
        value = story.engine.step
        next if value.nil?
        puts value
        puts "📌[#{story.engine.current_pointer}]"
    end


    puts "---" * 20
  end

  def test_navigate
    json = load_json_export("test/fixtures/hello-world.expanded.ink.json")
    story = RubyRedInk::Story.new(json)
    engine = story.engine

    assert_equal "Hello world", engine.navigate_down_tree(nil, parse_path("0.0"))
    assert_equal "\n", engine.navigate_down_tree(nil, parse_path("0.1"))
    assert_equal "We're going to make some really interesting stuff, aren't we?", engine.navigate_down_tree(nil, parse_path("0.2"))
    assert_equal "\n", engine.navigate_down_tree(nil, parse_path("0.3"))

    assert_equal :DONE, engine.navigate_down_tree(nil, parse_path("1"))
    assert_equal :DONE, engine.navigate_down_tree(nil, parse_path("0.g-0.0"))
  end

  def test_custom_divert_target
    json = load_json_export("test/fixtures/divert-targets.ink.json")
    story = RubyRedInk::Story.new(json)

    assert_nil story.engine.step

    result = <<~STORY
    Another day
    You sleep perchance to dream etc. etc.
    You didn't sleep
    STORY

    assert_equal result, story.engine.current_text + "\n"
  end
end