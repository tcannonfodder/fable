module RubyRedInk
  module Values
    VOID = :VOID_VALUE

    # VALUES NEED TO BE A CLASS THAT STORE THEIR PATH FOR NAVIGATION
    # CONTROLCOMMAND VALUE?

    def self.parse(value)
      return parse_divert(value) if is_divert?(value)
      return parse_variable_target(value) if is_variable_target?(value)
      return parse_choice_point(value) if is_choice_point?(value)
      return VOID if is_void?(value)
      return parse_string(value) if is_string?(value)
      return value if value.is_a?(Numeric)
    end

    def self.is_string?(value)
      value.is_a?(String) && (value.start_with?("^") || value == "\n")
    end

    def self.is_divert?(value)
      value.is_a?(Hash) && Divert.is_divert?(value)
    end

    def self.parse_divert(value)
      Divert.parse(value)
    end

    def self.is_variable_target?(value)
      value.is_a?(Hash) && VariableTarget.is_variable_target?(value)
    end

    def self.parse_variable_target(value)
      VariableTarget.parse(value)
    end

    def self.parse_string(value)
      if value.start_with?("^")
        value[1..-1]
      else
        value
      end
    end

    def self.is_void?(value)
      value == "void"
    end

    def self.is_choice_point?(value)
      value.is_a?(Hash) && value.has_key?("*")
    end

    def self.parse_choice_point(value)
      ChoicePoint::Choice.new(value)
    end

    def truthy?(value)
      truthy = false

      if value.is_a? DivertTargetValue
        add_error!("Shouldn't use a divert target (to #{value.target_path}) as a conditional value. Did you intend a function call 'likeThis()' or a read count check 'likeThis'? (no arrows)")
        return false
      end

      return value > 0
    end
  end
end