module RubyRedInk
  class Story
    attr_accessor :original_object, :root_container, :engine, :state

    def initialize(original_object)
      self.original_object = original_object
      self.state = StoryState.new
      self.engine = Engine.new(state, self)
      self.state.current_pointer = root.path_string
    end

    def root
      self.root_container ||= Container.new(original_object["root"], nil)
    end

    def ink_version
      original_object["inkVersion"]
    end

    def global_declaration
      root.nested_containers["global decl"]
    end
  end
end