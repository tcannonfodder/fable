module RubyRedInk
  module Values
    VOID = :VOID_VALUE

    # VALUES NEED TO BE A CLASS THAT STORE THEIR PATH FOR NAVIGATION
    # CONTROLCOMMAND VALUE?

    def self.parse(value)
      return parse_divergent(value) if is_divergent?(value)
      return VOID if is_void?(value)
      return parse_string(value) if is_string?(value)
      return value if value.is_a?(Numeric)
    end

    def self.is_string?(value)
      value.is_a?(String) && (value.start_with?("^") || value == "\n")
    end

    def self.is_divergent?(value)
      value.is_a?(Hash) && value.has_key?("^->")
    end

    def self.parse_divergent(value)
      value["^->"]
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
  end
end