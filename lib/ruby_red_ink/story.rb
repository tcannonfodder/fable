module RubyRedInk
  class Story
    attr_accessor :original_object, :root_container

    def initialize(original_object)
      self.original_object = original_object
      process_containers
    end

    def root
      self.root_container = Container.new(original_object["root"])
    end

    def ink_version
      original_object["inkVersion"]
    end
  end
end