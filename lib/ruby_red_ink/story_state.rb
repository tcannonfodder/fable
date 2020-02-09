module RubyRedInk
  class StoryState
    attr_accessor :state

    def initialize
      self.state = {}
    end

    def current_pointer=(value)
      state["current_pointer"] = value
    end

    def current_pointer
      state["current_pointer"]
    end
  end
end