module RubyRedInk
  class Engine
    attr_accessor :state, :story

    def initialize(state, story)
      self.state = state
      self.story = story
    end

    def step
      # debugger
      current_pointer_path = Path.parse(current_pointer)
      current_element = navigate_down_tree(nil, current_pointer_path)

      # We've hit a container, so need to go to the first element within the container and set that
      # as the current pointer
      if current_element.is_a?(Container)
        stack_to_move_to = current_element.stack
        element_to_move_to = stack_to_move_to.elements.first
        element_path = stack_to_move_to.path_string_for(element_to_move_to)
        self.current_pointer = element_path
        step
        return
      end

      puts current_element
      self.current_pointer = current_pointer.succ
      return
    end

    def navigate_down_tree(parent_stack, current_pointer_path)
      if current_pointer_path.empty?
        return parent_stack.elements.first
      end

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