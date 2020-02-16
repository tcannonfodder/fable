module RubyRedInk
  class CallStack
    attr_accessor :current_stack_index, :container_stack, :evaluation_stack, :state, :engine

    def initialize(container_stack, state, engine)
      @current_stack_index = 0
      @container_stack = container_stack
      @evaluation_stack = EvaluationStack.new
      @state = state
      @engine = engine

      if container_stack.container.record_visits? && !container_stack.container.count_start_only?
        state.record_visit(container_stack.container.path_string)
      end
    end

    def visits_for_current_container
      state.visits[container_stack.container.path_string]
    end

    def step
      puts "EVAL STACK ON STEP: #{evaluation_stack.stack.inspect}"
      if container_stack.container.record_visits? && container_stack.container.count_start_only?
        if current_stack_index == 0
          state.record_visit(container_stack.container.path_string)
        end
      end

      current_stack_element = container_stack.elements[current_stack_index]
      current_stack_path = container_stack.path_string_for_key(current_stack_index)
      @current_stack_index += 1

      # Process diverts first
      case current_stack_element
      when TunnelDivert
        return {
          action: :tunnel,
          element: current_stack_element,
          path: current_stack_path
        }
      when FunctionCallDivert
        return function_push(current_stack_element, current_stack_path)
      when StandardDivert
        if run_divert?(current_stack_element)
          puts "RUNNING DIVERT"
          target_element = engine.navigate_from(container_stack.container, current_stack_element.target)

          if target_element.is_a?(Container)
            return new_callstack(target_element.stack, current_stack_element.target)
          else
            current_stack_path = current_stack_element.target
            current_stack_element = target_element
          end
        else
          return noop(current_stack_element, current_stack_path)
        end
      end

      if current_stack_element.is_a?(Container)
        return new_callstack(current_stack_element.stack, current_stack_path)
      end

      if current_stack_element.nil?
        return tunnel_or_function_pop(current_stack_element, current_stack_path)
      end

      output_stream = StringIO.new

      if ControlCommands::COMMANDS.has_key?(current_stack_element)
        puts "COMMAND: #{current_stack_element}"
        case current_stack_element
        when :NOOP
          return noop(current_stack_element, current_stack_path)
        when :POP
          evaluation_stack.pop
          return noop(current_stack_element, current_stack_path)
        when :GLUE
          return glue(current_stack_element, current_stack_path)
        when :DONE, :TUNNEL_POP, :FUNCTION_POP
          return tunnel_or_function_pop(current_stack_element, current_stack_path)
        end

        if current_stack_element == :BEGIN_LOGICAL_EVALUATION_MODE
          # evaluation_stack = EvaluationStack.new

          # self.evaluation_stack << evaluation_stack

          reached_end = false

          while !reached_end
            next_item = container_stack.elements[self.current_stack_index]
            puts "EVAL MODE COMMAND: #{next_item}"
            case next_item
            when :SEED_RANDOM
              state.randomizer_seed = evaluation_stack.pop
              evaluation_stack.push(Values::VOID)
            when :END_LOGICAL_EVALUATION_MODE
              reached_end = true
            when :MAIN_STORY_OUTPUT
              output_stream << evaluation_stack.pop
            when :POP
              evaluation_stack.pop
            when :DUPLICATE_TOPMOST
              evaluation_stack.duplicate_topmost
            when :BEGIN_STRING_EVALUATION_MODE
              evaluation_stack.begin_string_evaluation_mode!
            when :END_STRING_EVALUATION_MODE
              evaluation_stack.end_string_evaluation_mode!
            when :NOOP
              next
            when :PUSH_CHOICE_COUNT
              raise NotImplementedError, "not tracking choice counts yet"
            when :PUSH_CHOICE_COUNT
              raise NotImplementedError, "turns not implemented yet"
            when :VISIT
              evaluation_stack.push(visits_for_current_container)
            when :SEQ
              raise NotImplementedError, "sequence count not implemented yet"
            when :CLONE_THREAD
              raise NotImplementedError, "Thread Cloning not done yet"
            when :DONE
              raise NotImplementedError, "EV MODE DONE not imeplemented yet"
            when :STORY_END
              raise NotImplementedError, "EV MODE END not imeplemented yet"
            when :ADDITION
              value_1 = evaluation_stack.pop
              value_2 = evaluation_stack.pop

              evaluation_stack.push(value_2 + value_1)
            when :SUBTRACTION
              value_1 = evaluation_stack.pop
              value_2 = evaluation_stack.pop

              evaluation_stack.push(value_2 - value_1)
            when :DIVIDE
              value_1 = evaluation_stack.pop
              value_2 = evaluation_stack.pop

              result = value_2 / value_1

              result = result.round(6) if result.is_a?(Float)

              evaluation_stack.push(result)
            when :MULTIPLY
              value_1 = evaluation_stack.pop
              value_2 = evaluation_stack.pop

              result = value_2 * value_1

              result = result.round(6) if result.is_a?(Float)

              evaluation_stack.push(result)
            when :MODULO
              value_1 = evaluation_stack.pop
              value_2 = evaluation_stack.pop

              evaluation_stack.push(value_2 % value_1)
            when :UNARY_NEGATE
              value_1 = evaluation_stack.pop

              evaluation_stack.push(~value_1)
            when :EQUALS
              value_1 = evaluation_stack.pop
              value_2 = evaluation_stack.pop
              puts "==: #{[value_1, value_2].inspect}"
              result = (value_2 == value_1) ? 1 : 0

              evaluation_stack.push(result)
            when :GREATER_THAN
              value_1 = evaluation_stack.pop
              value_2 = evaluation_stack.pop

              result = (value_2 > value_1) ? 1 : 0

              evaluation_stack.push(result)
            when :GREATER_THAN_OR_EQUAL_TO
              value_1 = evaluation_stack.pop
              value_2 = evaluation_stack.pop

              result = (value_2 >= value_1) ? 1 : 0

              evaluation_stack.push(result)
            when :LESS_THAN
              value_1 = evaluation_stack.pop
              value_2 = evaluation_stack.pop

              result = (value_2 < value_1) ? 1 : 0

              evaluation_stack.push(result)
            when :LESS_THAN_OR_EQUAL_TO
              value_1 = evaluation_stack.pop
              value_2 = evaluation_stack.pop

              result = (value_3 <= value_1) ? 1 : 0

              evaluation_stack.push(result)
            when :NOT_EQUAL
              value_1 = evaluation_stack.pop
              value_2 = evaluation_stack.pop

              result = (value_2 != value_1) ? 1 : 0

              evaluation_stack.push(result)
            when :UNARY_NOT
              value_1 = evaluation_stack.pop

              evaluation_stack.push(!value_1)
            when :AND
              value_1 = evaluation_stack.pop
              value_2 = evaluation_stack.pop

              result = (value_2 && value_1) ? 1 : 0

              evaluation_stack.push(result)
            when :OR
              value_1 = evaluation_stack.pop
              value_2 = evaluation_stack.pop

              result = (value_2 || value_2) ? 1 : 0

              evaluation_stack.push(result)
            when :MIN
              value_1 = evaluation_stack.pop
              value_2 = evaluation_stack.pop

              result = [value_1, value_2].min

              evaluation_stack.push(result)
            when :MAX
              value_1 = evaluation_stack.pop
              value_2 = evaluation_stack.pop

              result = [value_1, value_2].max

              evaluation_stack.push(result)
            when GlobalVariableTarget
              state.globals[next_item.name] = evaluation_stack.pop
            when VariableReference
              evaluation_stack.push(state.get_variable_value(next_item.name))
            when FunctionCallDivert
              run_embedded_engine(next_item.target)
            when StandardDivert
              puts "CHECKING DIVERT: #{next_item.target}"
              if run_divert?(next_item)
                puts "RUNNING EVAL DIVERT: #{next_item.target}"
                target_element = engine.navigate_from(container_stack.container, next_item.target)
                if target_element.is_a?(Container)
                  puts "RUNNING CONTAINER"
                  run_embedded_engine(next_item.target)
                else
                  puts "ELEMENT: #{target_element}"
                  if target_element != :NOOP
                    evaluation_stack.push(target_element)
                  end
                end
              end
            else
              evaluation_stack.push(next_item)
            end

            self.current_stack_index += 1
          end

          output_stream.rewind
          return {
            action: :output,
            element: output_stream.read,
            path: current_stack_path
          }
        end
      end

      return {
        action: :output,
        element: current_stack_element,
        path: current_stack_path
      }
    end

    def tunnel_or_function_pop(stack_element, path)
      return {
        action: :pop_stack,
        element: stack_element,
        path: path
      }
    end

    def glue(stack_element, path)
      {
        action: :glue,
        element: stack_element,
        path: path
      }
    end

    def noop(stack_element, path)
      {
        action: :noop,
        element: stack_element,
        path: path
      }
    end

    def pop(stack_element, path)
      {
        action: :pop,
        element: stack_element,
        path: path
      }
    end

    def new_callstack(stack, path)
      {
        action: :new_callstack,
        element: stack,
        path: path
      }
    end

    def set_randomizer_seed(value, path)
      {
        action: :set_randomizer_seed,
        element: value,
        path: path
      }
    end

    def function_push(stack_element,path)
      {
        action: :function,
        element: stack_element,
        path: path
      }
    end

    def run_embedded_engine(target)
      target_container = engine.navigate_from(container_stack.container, target)

      emedded_call_stack = CallStack.new(target_container.stack, state, engine)

      embedded_engine = Engine.new(state, engine.story, emedded_call_stack)
      embedded_engine.step

      evaluation_stack.push(embedded_engine.current_text)
    end
    def run_divert?(divert)
      run_divert = true
      if divert.is_conditional?
        # puts "DIVERT CHECK:"
        boolean_value = evaluation_stack.pop
        # puts "DIVERT CHECK: #{boolean_value}"
        run_divert = false if boolean_value == 0
      end

      run_divert
    end
  end

  class EvaluationStack
    include ControlCommands

    attr_accessor :stack, :string_evaluation_mode_stack, :mode

    def initialize
      puts "===NEW EVAL STACK==="
      self.stack = []
      self.string_evaluation_mode_stack = []
      self.mode = :evaluation_mode
    end

    def begin_string_evaluation_mode!
      self.mode = :string_evaluation_mode
    end

    def end_string_evaluation_mode!
      self.mode = :evaluation_mode
      push(string_evaluation_mode_stack.join)
      self.string_evaluation_mode_stack = []
    end

    def string_evaluation_mode?
      self.mode == :string_evaluation_mode
    end

    def push(value)
      # debugger if value.is_a?(StandardDivert)
      if string_evaluation_mode?
        puts "PUSH STR BEFORE -> #{value}: #{self.string_evaluation_mode_stack.inspect}"
        self.string_evaluation_mode_stack.unshift(value)
        puts "PUSH STR AFTER: #{self.string_evaluation_mode_stack.inspect}"
      else
        puts "PUSH BEFORE -> #{value}: #{self.stack.inspect}"
        self.stack.unshift(value)
        puts "PUSH AFTER: #{self.stack.inspect}"
      end
    end

    def pop
      if string_evaluation_mode?
        puts "POP STR BEFORE: #{self.string_evaluation_mode_stack.inspect}"
        x = self.string_evaluation_mode_stack.shift
        puts "POP STR AFTER: #{self.string_evaluation_mode_stack.inspect}"
        x
      else
        puts "POP BEFORE: #{self.stack.inspect}"
        x = self.stack.shift
        puts "POP AFTER: #{self.stack.inspect}"
        x
      end
    end

    def duplicate_topmost
      puts "DUP BEFORE: #{self.stack.inspect}"
      x = push(topmost.dup)
      puts "DUP AFTER: #{self.stack.inspect}"
      x
    end

    def topmost
      if string_evaluation_mode?
        self.string_evaluation_mode_stack.first
      else
        self.stack.first
      end
    end
  end
end