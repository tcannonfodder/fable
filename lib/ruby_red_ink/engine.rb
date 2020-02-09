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
      current_key, current_element = navigate_down_tree(nil, current_pointer_path)
      puts current_element
      # if current_element.is_a?(Container)
      #   self.current_pointer = Path.append_path_string(self.current_pointer, current_key+1)
      #   return
      # end

      if current_key.is_a?(Numeric)
        self.current_pointer = Path.append_path_string(self.current_pointer, current_key)
      else
        self.current_pointer = Path.append_path_string(self.current_pointer, current_key)
      end

      puts self.current_pointer

      return if current_element.is_a?(Container)

      puts current_element
      return
    end

    def navigate_down_tree(current_element, current_pointer_path)
      current_pointer_path.each do |current_key, rest_of_path|
        if current_key == Path::ROOT_PATH
          return navigate_down_tree(self.story.root, rest_of_path)
        end

        if rest_of_path.empty?
          return [current_key, current_element]
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