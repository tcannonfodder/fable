module RubyRedInk
  class VariableTarget
    class UnknownVariableTarget < RubyRedInk::Error ; end

    attr_accessor :original_object

    def self.parse(original_object)
      if original_object.has_key?("^->")
        return DivertVariableTarget.new(original_object)
      end

      if original_object.has_key?("VAR=")
        return GlobalVariableTarget.new(original_object)
      end

      if original_object.has_key?("temp=")
        return TemporaryVariableTarget.new(original_object)
      end

      raise UnknownVariableTarget, ""
    end


    def self.is_variable_target?(original_object)
      ["^->", "VAR=", "temp="].any? {|key| original_object.has_key?(key)}
    end


    def name
      raise NotImplementedError
    end

    def reassignment?
      original_object["re"] == true
    end

    def initialize(original_object)
      self.original_object = original_object
    end
  end

  class GlobalVariableTarget < VariableTarget
    def name
      original_object["VAR="]
    end
  end

  class TemporaryVariableTarget < VariableTarget
    def name
      original_object["temp="]
    end
  end

  class DivertVariableTarget < VariableTarget
    def name
      original_object["^->"]
    end
  end
end