require_relative "test_helper"

class StoryTest < Minitest::Test
  def test_load_hello_world
    json = load_json_export("test/fixtures/hello-world.expanded.ink.json")
    story = RubyRedInk::Story.new(json)
    story.root
    debugger
    puts story.engine.step
    puts story.engine.step
    puts story.engine.step
    puts story.engine.step
  end

end