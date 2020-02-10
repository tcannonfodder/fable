module RubyRedInk
  class CallStack
    attr_accessor :current_stack_index, :container_stack

    def initialize(container_stack)
      @current_stack_index = 0
      @container_stack = container_stack
    end

    def step
      current_stack_element = container_stack.elements[current_stack_index]
      current_stack_path = container_stack.path_string_for_key(current_stack_index)
      @current_stack_index += 1
      if current_stack_element.is_a?(Container)
        return {
          action: :new_callstack,
          element: current_stack_element.stack,
          path: current_stack_path
        }
      end

      if current_stack_element.nil? || current_stack_element == ControlCommands.get_control_command('done')
        return {
          action: :pop_stack,
          element: current_stack_element,
          path: current_stack_path
        }
      end

      return {
        action: :output,
        element: current_stack_element,
        path: current_stack_path
      }
    end
  end
end