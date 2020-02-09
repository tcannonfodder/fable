require_relative "test_helper"

class ControlCommandsTest < Minitest::Test
  def test_lookup
    assert RubyRedInk::ControlCommands.is_control_command?("ev")
    assert !RubyRedInk::ControlCommands.is_control_command?("blah")
    assert !RubyRedInk::ControlCommands.is_control_command?(nil)
    assert !RubyRedInk::ControlCommands.is_control_command?(build_container([5,6, nil]))
  end
end