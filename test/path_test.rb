require_relative "test_helper"

class PathTest < Minitest::Test
  def test_root_container_path
    assert_equal ({
      RubyRedInk::Path::ROOT_PATH => {"building" => {"entrance" => {3 => {0 => {}}}}}
    }), RubyRedInk::Path.parse("building.entrance.3.0")
  end

  def test_relative_path
    assert_equal ({
      RubyRedInk::Path::RELATIVE_PATH => { RubyRedInk::Path::PARENT => { 1 => {}}}
    }), RubyRedInk::Path.parse(".^.1")
  end
end