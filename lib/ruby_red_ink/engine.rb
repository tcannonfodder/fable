module RubyRedInk
  class Engine
    attr_accessor :state, :story

    def initialize(state, story)
      self.state = state
      self.story = story
    end

    def step
      current_pointer_path = Path.parse(current_pointer)
      puts current_pointer_path
      current_position = navigate_down_tree(nil, current_pointer_path)
      puts current_position
      current_position.elements.each do |element|
        if element.is_a?(Container)
          self.current_pointer = element.path_string
          return
        end
        puts element
      end
    end

    def navigate_down_tree(current_element, current_pointer_path)
      current_pointer_path.each do |current_key, rest_of_path|
        if current_key == Path::ROOT_PATH
          return navigate_down_tree(self.story.root, rest_of_path)
        end

        if rest_of_path.empty?
          return current_element
        end

        return navigate_down_tree(current_element.elements[current_key], rest_of_path)
      end
    end

    def current_pointer=(value)
      state.current_pointer = value
    end

    def current_pointer
      state.current_pointer
    end
  end
end