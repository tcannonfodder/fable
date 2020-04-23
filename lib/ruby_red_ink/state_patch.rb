module RubyRedInk
  class StatePatch
    attr_accessor :globals, :changed_variables, :visit_counts, :turn_indicies

    def initialize(state_patch_to_copy = nil)
      if state_patch_to_copy.nil?
        self.globals = {}
        self.changed_variables = Set.new
        self.visit_counts = {}
        self.turn_indicies = {}
      else
        self.globals = Hash[state_patch_to_copy.globals]
        self.changed_variables = state_patch_to_copy.changed_variables.dup
        self.visit_counts = Hash[state_patch_to_copy.visit_counts]
        self.turn_indicies = Hash[state_patch_to_copy.turn_indicies]
      end
    end

    def get_global(name)
      return self.globals[name]
    end

    def set_global(name, value)
      self.globals[name] = value
    end

    def add_changed_variable(name)
      self.changed_variables << name
    end

    def get_visit_count(container)
      self.visit_counts[container]
    end

    def set_visit_count(container, count)
      self.visit_counts[container] = count
    end

    def set_turn_index(container, count)
      self.turn_indicies[container] = count
    end

    def get_turn_index(container)
      self.turn_indicies[container]
    end
  end
end