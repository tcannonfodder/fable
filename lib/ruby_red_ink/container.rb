module RubyRedInk
  class Container
    attr_accessor :original_object, :elements, :nested_containers, :final_attribute, :record_visits, :record_turn_index, :count_start_only, :path_string

    def initialize(original_object, parent_path_string, fallback_identifier = 0)
      self.original_object = original_object
      self.final_attribute = original_object.last

      self.path_string = Path.append_path_string(parent_path_string, (name || fallback_identifier))
      process_elements
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

    def process_elements
      self.elements = []

      original_object[0..-2].each_with_index do |value, index|
        if value.is_a?(Array)
          elements << self.class.new(value, path_string, index)
          next
        end

        if ControlCommands.is_control_command?(value)
          elements << ControlCommands.get_control_command(value)
          next
        end

        elements << Values.parse(value)
      end
    end

    def process_nested_containers
      self.nested_containers = {}
      return if !has_metadata?

      final_attribute.each do |key, nested_container|
        next if key == "#n" || key == "#f"
        nested_containers[key] = self.class.new(nested_container, path_string, key)
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

  end
end