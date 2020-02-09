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
      puts [current_key, current_element]


      if current_element.is_a?(Container)
        self.current_pointer = Path.append_path_string(current_element.path_string, 0)
        puts self.current_pointer
        return
      end

      if current_key.is_a?(Numeric)
        self.current_pointer = current_pointer.succ
      end
      # else
      #   self.current_pointer = Path.append_path_string(self.current_pointer, current_key)
      # end

      puts self.current_pointer
      puts current_element
      return
    end

    def navigate_down_tree(parent_stack, current_pointer_path)
      current_pointer_path.each do |current_key, rest_of_path|
        # If we're at the root path, start traveling recursively down the
        # stacks, starting with the root container's stack.
        if current_key == Path::ROOT_PATH
          return navigate_down_tree(self.story.root.stack, rest_of_path)
        end

        future_element = parent_stack.element_tree[current_key]

        if future_element.is_a?(Container)
          return navigate_down_tree(future_element.stack, rest_of_path)
        end

        return future_element
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