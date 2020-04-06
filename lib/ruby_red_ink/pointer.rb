module RubyRedInk
  class Pointer
    attr_accessor :container, :index

    def self.start_of(container)
      self.new(container, 0)
    end

    def self.null_pointer
      self.new(nil, -1)
    end

    def initialize(container, index)
      self.container = container
      self.index = index
    end

    def resolve!
      return nil if index < 0
      return nil if container.nil?
      return container if container.content.empty?
      return container.content[index]
    end

    def null_pointer?
      container.nil?
    end

    def path
      return nil if null_pointer?
      if index > 0
        return container.path.append_component(index)
      else
        return container.path
      end
    end
  end
end