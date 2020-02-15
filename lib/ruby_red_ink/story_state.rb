module RubyRedInk
  class StoryState
    attr_accessor :state

    def initialize
      self.state = {}
    end

    def randomizer
      if state["randomizer_seed"].present?
        randomizer = Random.new(state["randomizer_seed"])
      else
        randomizer = Random.new
        randomizer_seed = randomizer.seed
      end

      randomizer
    end

    def randomizer_seed=(value)
      state["randomizer_seed"] = value
    end

    def current_pointer=(value)
      state["current_pointer"] = value
    end

    def current_pointer
      state["current_pointer"]
    end

    def globals
      state["global_variables"] ||= {}
    end

    def temporary_variables
      state["temporary_variables"] ||= {}
    end

    def visits
      state["visits"] ||= {}
    end

    def get_variable_value(name)
      result = globals[name] || temporary_variables[name]
    end

    def record_visit(container_path)
      puts "=== RECORD VISIT: #{container_path} ===="
      if visits.has_key?(container_path)
        visits[container_path] += 1
      else
        visits[container_path] ||= 0
      end
    end
  end
end