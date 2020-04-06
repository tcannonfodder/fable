module RubyRedInk
  class Value < RuntimeObject
    attr_accessor :value_object
    alias_method :value, :value_object
    alias_method :value=, :value_object=


    def initialize(value)
      self.value_object = value
    end

    def value_type
      raise NotImplementedError
    end

    def truthy?
      raise NotImplementedError
    end

    def cast!(new_type)
      raise NotImplementedError
    end

    def to_s
      value_object.to_s
    end

    def self.create(value)
      case value
      when TrueClass, FalseClass
        converted_to_int = value ? 1 : 0
        return IntValue.new(converted_to_int)
      when Integer
        return IntValue.new(value)
      when Numeric
        return FloatValue.new(value.to_f)
      when String
        return StringValue.new(value)
      when Path
        return DivertTargetValue.new(value)
      when InkList
        return ListValue.new(value)
      else
        return nil
      end
    end

    def copy
      return self.class.create(value_object)
    end

    def bad_cast_exception(target_type)
      return StoryError.new("Can't cast #{self.value_object} from #{self.value_type} to #{target_type}")
    end
  end

  class IntValue < Value
    def value_type
      return OrderedValueTypes[IntValue]
    end

    def truthy?
      return value != 0
    end

    def initialize
      super(0)
    end

    def cast!(new_type)
      if new_type == self.value_type
        return self
      end

      if new_type == OrderedValueTypes[FloatValue]
        return FloatValue.new(self.value.to_f)
      end

      if new_type == OrderedValueTypes[StringValue]
        return StringValue.new(self.value.to_s)
      end

      raise bad_cast_exception(new_type)
    end
  end

  class FloatValue < Value
    def value_type
      return OrderedValueTypes[FloatValue]
    end

    def truthy?
      return value != 0.0
    end

    def initialize
      super(0.0)
    end

    def cast!(new_type)
      if new_type == self.value_type
        return self
      end

      if new_type == OrderedValueTypes[IntValue]
        return IntValue.new(self.value.to_i)
      end

      if new_type == OrderedValueTypes[StringValue]
        return StringValue.new(self.value.to_s)
      end

      raise bad_cast_exception(new_type)
    end
  end

  class StringValue < Value
    attr_accessor :is_newline, :is_inline_whitespace

    alias_method :is_newline?, :is_newline
    alias_method :is_inline_whitespace?, :is_inline_whitespace

    def value_type
      return OrderedValueTypes[StringValue]
    end

    def truthy?
      return value.length > 0
    end

    def is_nonwhitespace?
      return !is_newline? && !is_inline_whitespace?
    end

    def initialize(*args)
      if args.size == 1
        self.initialize_with_string(args[0])
      else
        super("")
      end
    end

    def initialize_with_string(value)
      #classify whitespace status
      self.is_newline = (value == "\n")
      self.is_inline_whitespace = true

      value.each_char do |character|
        if character != ' ' && character != "\t"
          self.is_inline_whitespace = false
          break
        end
      end
    end

    def cast!(new_type)
      if new_type == self.value_type
        return self
      end

      if new_type == OrderedValueTypes[IntValue]
        begin
          return IntValue.new(Integer(self.value))
        rescue ArgumentError => e
          return nil
        end
      end

      if new_type == OrderedValueTypes[FloatValue]
        begin
          return FloatValue.new(Float(self.value))
        rescue ArgumentError => e
          return nil
        end
      end

      raise bad_cast_exception(new_type)
    end
  end

  class DivertTargetValue < Value
    alias_method :target_path, :value
    alias_method :target_path=, :value=

    def value_type
      return OrderedValueTypes[DivertTargetValue]
    end

    def truthy?
      raise Error, "Shouldn't be checking the truthiness of a divert target"
    end

    def initialize
      super(nil)
    end

    def cast!(new_type)
      if new_type == value_type
        return self
      end

      raise bad_cast_exception(new_type)
    end

    def to_s
      return "DivertTargetValue(#{target_path})"
    end
  end

  class VariablePointerValue < Value
    # Where the variable is located
    # -1 = default, unknown, to be determined
    # 0 = in global scope
    # 1+ = callstack element index + 1 (so that the first doesn't conflict with special global scope)
    attr_accessor :context_index

    alias_method :variable_name, :value
    alias_method :variable_name=, :value=

    def value_type
      return OrderedValueTypes[VariablePointerValue]
    end

    def truthy?
      raise Error, "Shouldn't be checking the truthiness of a variable pointer"
    end

    def initialize(variable_name, context_index = -1)
      super(variable_name)
      self.context_index = context_index
    end

    def initialize
      super(nil)
    end

    def cast!(new_type)
      if new_type == value_type
        return self
      end

      raise bad_cast_exception(new_type)
    end

    def to_s
      return "VariablePointerValue(#{variable_name})"
    end

    def copy
      return VariablePointerValue.new(variable_name, context_index)
    end
  end

  class ListValue < Value
    def value_type
      return OrderedValueTypes[ListValue]
    end

    def truthy?
      return value.size > 0
    end

    def cast(new_type)
      if new_type == OrderedValueTypes[IntValue]
        max = value.max_item
        if max.nil?
          return IntValue.new(0)
        else
          return IntValue.new(max)
        end
      end

      if new_type == OrderedValueTypes[FloatValue]
        max = value.max_item
        if max.nil?
          return FloatValue.new(0.0)
        else
          return FloatValue.new(max)
        end
      end

      if new_type == OrderedValueTypes[StringValue]
        max = value.max_item
        if max.nil?
          return StringValue.new("")
        else
          return StringValue.new(max)
        end
      end

      if new_type == value_type
        return self
      end

      raise bad_cast_exception(new_type)
    end

    def initialize
      super(InkList.new)
    end

    def initialize(single_item, single_value)
      self.value = InkList.new([single_item, single_value])
    end

    def retain_list_origins_for_assignment(old_value, new_value)
      # When assigning the empty list, try to retain any initial origin names
      if (old_value.is_a?(ListValue) && new_value.is_a?(ListValue) && new_value.value.size == 0)
        new_list.value.set_initial_origin_names(old_value.value.origin_names)
      end
    end
  end

  OrderedValueTypes = {
    # Used in coercion
    IntValue => 0,
    FloatValue => 1,
    ListValue => 2,
    StringValue => 3,

    # Not used for coercion described above
    DivertTargetValue => 4,
    VariablePointerValue => 5
  }.freeze
end