require_relative "test_helper"

class StoryTest < Minitest::Test
  def test_load_hello_world
    json = load_json_export("test/fixtures/hello-world.expanded.ink.json")
    story = RubyRedInk::Story.new(json)
    story.root
    puts "---" * 20

    puts story.engine.step
    puts story.engine.step
    puts story.engine.step
    puts story.engine.step
    puts story.engine.step
    puts story.engine.step
    puts story.engine.step
    puts story.engine.step
    puts story.engine.step
    puts story.engine.step
    puts story.engine.step

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
end