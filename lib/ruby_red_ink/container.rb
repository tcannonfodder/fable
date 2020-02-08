module RubyRedInk
  class Container
    attr_accessor :original_object, :final_attribute, :record_visits, :record_turn_index, :count_start_only

    def initialize(original_object)
      self.original_object = original_object
      self.final_attribute = original_object.last
      self.name = name
      process_bit_flags
    end

    def has_metadata?
      !final_attribute.nil?
    end

    def name
      return nil if !has_metadata?
      final_attribute["#n"]
    end

    def subContainers
      return [] if !has_metadata?
      final_attribute["subContainers"]
    end

    def has_bit_flags?
      return false if !has_metadata?
      final_attribute["#f"].is_a?(Numeric)
    end

    def process_bit_flags
      if has_bit_flags?
        record_visits = final_attribute & 0x1
        record_turn_index = final_attribute & 0x2
        count_start_only = final_attribute & 0x4
      else
        record_visits = false
        record_turn_index = false
        count_start_only = false
      end
    end
  end
end