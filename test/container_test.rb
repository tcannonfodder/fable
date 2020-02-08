require_relative "test_helper"

class ContainerTest < Minitest::Test
  def test_build_simple_container
    container = build_container([5,6, nil])

    assert_nil container.name
    assert !container.has_metadata?
    assert_equal [5,6], container.values
  end

  def test_build_simple_named_container
    container = build_container(["^Hello world", {"#n" => "hello"}])

    assert_equal "hello", container.name
    assert container.has_metadata?

    assert_equal ["Hello world"], container.values
  end

  def test_build_nested_containers
    container_object = ["^test", {"subContainer" => [5, 6, nil], "#f" => 3}]
    container = build_container(container_object)

    assert_nil container.name
    assert container.has_metadata?

    assert_equal ["test"], container.values
    assert_equal 1, container.nested_containers.size

    nested_container = container.nested_containers["subContainer"]
    assert_nil nested_container.name
    assert !nested_container.has_metadata?
    assert [5,6], nested_container.values
  end

  def test_bit_flag_parsing
    container = build_container([5, {"#f" => 1}])

    assert container.record_visits?
    assert !container.record_turn_index?
    assert !container.count_start_only?

    container = build_container([5, {"#f" => 2}])

    assert !container.record_visits?
    assert container.record_turn_index?
    assert !container.count_start_only?

    container = build_container([5, {"#f" => 3}])

    assert container.record_visits?
    assert container.record_turn_index?
    assert !container.count_start_only?

    container = build_container([5, {"#f" => 4}])

    assert !container.record_visits?
    assert !container.record_turn_index?
    assert container.count_start_only?

    container = build_container([5, {"#f" => 5}])

    assert container.record_visits?
    assert !container.record_turn_index?
    assert container.count_start_only?

    container = build_container([5, {"#f" => 6}])

    assert !container.record_visits?
    assert container.record_turn_index?
    assert container.count_start_only?

    container = build_container([5, {"#f" => 7}])

    assert container.record_visits?
    assert container.record_turn_index?
    assert container.count_start_only?
  end
end