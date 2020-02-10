module RubyRedInk
  class CallStack
    attr_accessor :current_stack_index, :container_stack, :evaluation_stacks

    def initialize(container_stack)
      @current_stack_index = 0
      @container_stack = container_stack
      @evaluation_stacks = []
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

      if current_stack_element.nil? || current_stack_element == ControlCommands::COMMANDS[:DONE]
        return {
          action: :pop_stack,
          element: current_stack_element,
          path: current_stack_path
        }
      end

      if ControlCommands::COMMANDS.has_key?(current_stack_element)
        if current_stack_element == :BEGIN_LOGICAL_EVALUATION_MODE
          evaluation_stack = EvaluationStack.new
          self.evaluation_stacks << evaluation_stack
          self.current_stack_index += 1

          reached_end = false
          items_in_evaluation_stack = []
          debugger
          while !reached_end
            next_item = container_stack.elements[self.current_stack_index]

            if next_item == :END_LOGICAL_EVALUATION_MODE
              reached_end = true
            else
              items_in_evaluation_stack << next_item
            end
            self.current_stack_index += 1
          end

          debugger
          items_in_evaluation_stack
        end
      end

      return {
        action: :output,
        element: current_stack_element,
        path: current_stack_path
      }
    end

    def process_control_command(current_stack_element)

    end
  end

  class EvaluationStack
    include ControlCommands

    attr_accessor :stack

    def intialize
      stack =[]
    end

    def add_to_stack(value)
      stack << value
    end
  end
end