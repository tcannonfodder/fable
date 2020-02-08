require "test_helper"

class RubyRedInkTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::RubyRedInk::VERSION
  end

  def test_it_does_something_useful
    assert false
  end

  def test_loads_json
    refute_empty load_json_export
  end

# irb(main):018:0> if(4 & 0x1)
# irb(main):019:1> puts 2
# irb(main):020:1> end
# 2
# => nil
# irb(main):021:0> (1..5).map{|x| x & 0x1}
# => [1, 0, 1, 0, 1]
# irb(main):022:0> (1..5).map{|x| x & 0x2}
# => [0, 2, 2, 0, 0]
# irb(main):023:0> (1..5).map{|x| x & 0x4}
end
