module Fable
  # The value to be assigned is popped off the evaluation stack,
  # so no need to keep it here
  class VariableAssignment < RuntimeObject
    attr_accessor :variable_name, :new_declaration, :global

    alias_method :new_declaration?, :new_declaration
    alias_method :global?, :global

    def initialize(variable_name, new_declaration)
      super()
      self.variable_name = variable_name
      self.new_declaration = new_declaration
    end

    def to_s
      return "VarAssign to #{variable_name}"
    end
  end
end