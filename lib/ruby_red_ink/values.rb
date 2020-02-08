module RubyRedInk
  module Values
    VOID = :VOID_VALUE

    def parse(value)
      return parse_divergent(value) if is_divergent?(value)
      return VOID if is_void?
      return parse_string(value) if is_string?(value)
      return value if value.is_a?(Numeric)
    end

    def is_string?(value)
      (value.start_with?("^") || value == "\n")
    end

    def is_divergent?(value)
      value.is_a?(Hash)
      value.has_key?("^->")
    end

    def parse_divergent(value)
      value["^->"]
    end

    def parse_string(value)
      if value.start_with?("^")
        value[1..-1]
      else
        value
      end
    end

    def is_void?(value)
      value == "void"
    end
  end
end