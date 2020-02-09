module RubyRedInk
  class Engine
    attr_accessor :state, :story, :call_stacks, :current_call_stack

    def initialize(state, story)
      self.state = state
      self.story = story
      self.call_stacks = [CallStack.new]
      self.current_call_stack = call_stacks.first
    end

    def step
      puts ({stacks: call_stacks.size, current: current_call_stack})
      if current_call_stack.nil?
        return "💥"
      end
      value_from_stack = current_call_stack.step
      if value_from_stack.is_a?(CallStack)
        call_stacks << value_from_stack
        self.current_call_stack = value_from_stack
        return '-'
      elsif value_from_stack == ControlCommands.get_control_command('done')
        call_stacks.delete(current_call_stack)
        self.current_call_stack = call_stacks.last
        return value_from_stack
      else
        return value_from_stack
      end
    end

    # def step
    #   puts current_pointer
    #   current_pointer_path = Path.parse(current_pointer)
    #   current_element = navigate_down_tree(nil, current_pointer_path)

    #   # We've hit a container, so need to go to the first element within the container and set that
    #   # as the current pointer
    #   if current_element.is_a?(Container)
    #     stack_to_move_to = current_element.stack
    #     element_to_move_to = stack_to_move_to.elements.first
    #     element_path = stack_to_move_to.path_string_for(element_to_move_to)
    #     self.current_pointer = element_path
    #     return
    #   end

    #   if current_element.nil?
    #     self.current_pointer = Path.jump_up_level(current_pointer).succ
    #     return
    #   end

    #   self.current_pointer = current_pointer.succ
    #   return current_element
    # end

    # def navigate_down_tree(parent_stack, current_pointer_path)
    #   if current_pointer_path.empty?
    #     return parent_stack.elements.first
    #   end

    #   current_pointer_path.each do |current_key, rest_of_path|
    #     # If we're at the root path, start traveling recursively down the
    #     # stacks, starting with the root container's stack.
    #     if current_key == Path::ROOT_PATH
    #       return navigate_down_tree(self.story.root.stack, rest_of_path)
    #     end

    #     future_element = parent_stack.element_tree[current_key]

    #     if future_element.is_a?(Container)
    #       return navigate_down_tree(future_element.stack, rest_of_path)
    #     end

    #     return future_element
    #   end
    # end

    def current_pointer=(value)
      state.current_pointer = value
    end

    def current_pointer
      state.current_pointer
    end
  end
end