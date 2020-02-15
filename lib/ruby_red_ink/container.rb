module RubyRedInk
  class Container
    attr_accessor :original_object, :parent, :path_string,
      :stack, :elements_array,
      :nested_containers,
      :final_attribute,
      :record_visits, :record_turn_index, :count_start_only

    def initialize(original_object, parent, fallback_identifier = 0)
      self.original_object = original_object
      self.final_attribute = original_object.last
      self.parent = parent

      if parent.nil?
        self.path_string = ""
      else
        self.path_string = Path.append_path_string(parent.path_string, (name || fallback_identifier))
      end

      build_stack
      process_nested_containers
      process_bit_flags
    end

    def has_metadata?
      !final_attribute.nil?
    end

    def name
      return nil if !has_metadata?
      final_attribute["#n"]
    end

    def has_bit_flags?
      return false if !has_metadata?
      bit_flag.is_a?(Numeric)
    end

    def bit_flag
      final_attribute["#f"]
    end

    def build_stack
      @elements_array = []

      original_object[0..-2].each_with_index do |value, index|
        if value.is_a?(Array)
          @elements_array << self.class.new(value, self, index)
          next
        end

        if ControlCommands.is_control_command?(value)
          @elements_array << ControlCommands.get_control_command(value)
          next
        end

        @elements_array << Values.parse(value)
      end

      self.stack = ContainerStack.new(self)
    end

    def process_nested_containers
      self.nested_containers = {}
      return if !has_metadata?

      final_attribute.each do |key, nested_container|
        next if key == "#n" || key == "#f"
        nested_containers[key] = self.class.new(nested_container, self, key)
      end
    end

    def process_bit_flags
      if has_bit_flags?
        self.record_visits = (bit_flag & 0x1) > 0
        self.record_turn_index = (bit_flag & 0x2) > 0
        self.count_start_only = (bit_flag & 0x4) > 0
      else
        self.record_visits = false
        self.record_turn_index = false
        self.count_start_only = false
      end
    end

    def record_visits?
      record_visits
    end

    def record_turn_index?
      record_turn_index
    end

    def count_start_only?
      count_start_only
    end

    def all_named_containers
      non_numeric_tree_keys = stack.element_tree.keys.reject{|x| x.is_a?(Numeric)}
      containers_from_tree = stack.element_tree.slice(non_numeric_tree_keys)
      nested_containers.merge.merge(containers_from_tree)
    end

  end
end