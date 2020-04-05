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

      if original_object.has_key?("VAR?")
        return VariableReference.new(original_object)
      end

      raise UnknownVariableTarget, ""
    end


    def self.is_variable_target?(original_object)
      ["^->", "VAR=", "temp=", "VAR?"].any? {|key| original_object.has_key?(key)}
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

    def target
      name
    end

    def is_conditional?
      original_object["c"] == true
    end

    def pushes_to_stack?
      false
    end
  end

  class VariableReference < VariableTarget
    def name
      original_object["VAR?"]
    end
  end
end