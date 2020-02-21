module RubyRedInk
  class CallStack
    attr_accessor :current_stack_index, :container_stack, :evaluation_stack, :state, :engine, :debug_padding

    def initialize(container_stack, state, engine, debug_padding = 0)
      @debug_padding = debug_padding
      @current_stack_index = 0
      @container_stack = container_stack
      @evaluation_stack = EvaluationStack.new(@debug_padding)
      @state = state
      @engine = engine

      if container_stack.container.record_visits? && !container_stack.container.count_start_only?
        state.record_visit(container_stack.container.path_string)
      end
    end

    def clone_attributes
      {
        container_stack: container_stack.dup,
        current_stack_index: current_stack_index.dup,
        evaluation_stack_attributes: evaluation_stack.clone_attributes
      }
    end

    def rebuild_from_attributes(attributes)
      self.container_stack = attributes[:container_stack]
      self.current_stack_index = attributes[:current_stack_index]
      self.evaluation_stack.rebuild_from_attributes(attributes[:evaluation_stack_attributes])
    end

    def visits_for_current_container
      state.visits[container_stack.container.path_string]
    end

    def print_padding
      return "" if @debug_padding <= 0
      "#{'  ' * @debug_padding}-->"
    end

    def step
      puts "#{print_padding}EVAL STACK ON STEP: #{evaluation_stack.stack.inspect} . STRING EVAL STACK #{evaluation_stack.string_evaluation_mode_stack.inspect}"
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
      when ChoicePoint::Choice
        if add_choice?(current_stack_element)
          if current_stack_element.has_choice_only_content?
            current_stack_element.choice_only_content = evaluation_stack.pop
          end

          if current_stack_element.has_start_content?
            current_stack_element.start_content = evaluation_stack.pop
          end

          current_stack_element.thread_at_generation = clone_attributes
          puts "#{print_padding}ADDING CHOICE #{current_stack_path}, #{current_stack_element.path_when_chosen}"
          return new_choice_point(current_stack_element, current_stack_path)
        else
          return tunnel_or_function_pop(current_stack_element, current_stack_path)
        end
      when TunnelDivert
        return {
          action: :tunnel,
          element: current_stack_element,
          path: current_stack_path
        }
      when GlobalVariableTarget
        state.globals[current_stack_element.name] = evaluation_stack.pop
      when TemporaryVariableTarget
        state.temporary_variables[current_stack_element.name] = evaluation_stack.pop
        return noop(current_stack_element, current_stack_path)
      when FunctionCallDivert
        return function_push(current_stack_element, current_stack_path)
      when StandardDivert
        puts "#{print_padding}RUNNING DIVERT Outside Loop"
        process_standard_divert(current_stack_element)
        return noop(current_stack_element, current_stack_path)
      when VariableTargetDivert
        puts "#{print_padding}RUNNING VARIABLE TARGET DIVERT"
        target_divert = state.get_variable_value(current_stack_element.target)
        process_standard_divert(target_divert)
        return noop(current_stack_element, current_stack_path)
      end

      if current_stack_element.is_a?(Container)
        return new_callstack(current_stack_element.stack, current_stack_path)
      end

      if current_stack_element.nil?
        return tunnel_or_function_pop(current_stack_element, current_stack_path)
      end

      puts ("#{print_padding}#{{path: current_stack_path, element: current_stack_element}}")

      output_stream = StringIO.new

      if ControlCommands::COMMANDS.has_key?(current_stack_element)
        # puts "#{print_padding}COMMAND: #{current_stack_element}"
        case current_stack_element
        when :NOOP, :END_LOGICAL_EVALUATION_MODE
          return noop(current_stack_element, current_stack_path)
        when :POP
          evaluation_stack.pop
          return noop(current_stack_element, current_stack_path)
        when :GLUE
          return glue(current_stack_element, current_stack_path)
        when :DONE
          return thread_done(current_stack_element, current_stack_path)
        when :TUNNEL_POP, :FUNCTION_POP
          return tunnel_or_function_pop(current_stack_element, current_stack_path)
        when :STORY_END
          return story_end(current_stack_element, current_stack_path)
        when :CLONE_THREAD
          return clone_thread(current_stack_path)
        when :DUPLICATE_TOPMOST
          evaluation_stack.duplicate_topmost
          return noop(current_stack_element, current_stack_path)
        end

        if current_stack_element == :BEGIN_LOGICAL_EVALUATION_MODE
          # evaluation_stack = EvaluationStack.new

          # self.evaluation_stack << evaluation_stack

          reached_end = false

          while !reached_end
            next_item = container_stack.elements[self.current_stack_index]
            if next_item.nil?
              return noop(next_item, container_stack.path_string_for(next_item))
            end
            puts ("#{print_padding}#{{eval_mode: "🐧", string_mode: "#{'🐦' if evaluation_stack.mode == :string_evaluation_mode}", path: container_stack.path_string_for(next_item), element: next_item}}")
            puts "#{print_padding}EVAL MODE COMMAND: #{next_item}"
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
              1 #do nothing
            when :PUSH_CHOICE_COUNT
              evaluation_stack.push(state.current_choices.count)
            when :PUSH_CHOICE_COUNT
              raise NotImplementedError, "turns not implemented yet"
            when :VISIT
              evaluation_stack.push(visits_for_current_container)
            when :SEQ
              evaluation_stack.push(next_sequence_shuffle_index)
            when :CLONE_THREAD
              raise NotImplementedError, "EV MODE Thread Cloning not done yet"
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
              puts "#{print_padding}==: #{[value_1, value_2].inspect}"
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

              result = ((value_2 > 0) && (value_1 > 0)) ? 1 : 0
              evaluation_stack.push(result)
            when :OR
              value_1 = evaluation_stack.pop
              value_2 = evaluation_stack.pop

              result = ((value_1 > 0) || (value_2 > 0)) ? 1 : 0

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
            when TemporaryVariableTarget
              state.temporary_variables[next_item.name] = evaluation_stack.pop
            when VariableReference
              evaluation_stack.push(state.get_variable_value(next_item.name))
            when FunctionCallDivert
              run_embedded_engine(next_item.target)
            when StandardDivert
              result = process_standard_divert(next_item)
              if result == :divert_not_taken
                self.current_stack_index += 1
              end
              next
            when VariableTargetDivert
              puts "#{print_padding}RUNNING EVAL MODE VARIABLE TARGET DIVERT"
              target_divert = state.get_variable_value(next_item.target)
              result = process_standard_divert(target_divert)
              if result == :divert_not_taken
                self.current_stack_index += 1
              end
              next
            else
              evaluation_stack.push(next_item)
            end
            puts "#{print_padding}⏱"
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

    def clone_thread(path)
      {
        action: :clone_thread,
        element: self.container_stack,
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

    def story_end(stack_element, path)
      {
        action: :story_end,
        element: stack_element,
        path: path
      }
    end

    def thread_done(stack_element, path)
      {
        action: :thread_done,
        element: stack_element,
        path: path
      }
    end

    def new_choice_point(stack_element, path)
      {
        action: :new_choice_point,
        element: stack_element,
        path: path
      }
    end

    def process_standard_divert(divert)
      puts "#{print_padding}CHECKING DIVERT: #{divert.target}"
      if run_divert?(divert)
        puts "#{print_padding}RUNNING EVAL DIVERT: #{divert.target}"
        target_element = engine.navigate_from(container_stack.container, divert.target)
        if target_element.is_a?(Container)
          if divert.pushes_to_stack?
            puts "#{print_padding}RUNNING CONTAINER, PUSHING RESULT TO STACK"
            run_embedded_engine(divert.target)
          else
            if new_container_stack_empty?(target_element.stack)
              puts "#{print_padding}EMPTY STACK, ACTING AS A POINTER"
              new_container_stack = target_element.parent.stack
              new_stack_index = target_element.parent.elements_array.index(target_element)
              switch_to_container_stack(new_container_stack, new_stack_index + 1)
            else
              puts "#{print_padding}NEW SWITCH EVERYBODY"
              switch_to_container_stack(target_element.stack, divert.target.split(".").last.to_i)
            end
          end
        else
          if divert.pushes_to_stack?
            puts "#{print_padding}ELEMENT: #{target_element}"
            if target_element != :NOOP
              evaluation_stack.push(target_element)
            end
          else
            new_container_stack = engine.closest_container_for(container_stack.container, divert.target).stack
            if new_container_stack_empty?(new_container_stack)
              puts "#{print_padding}EMPTY STACK, ACTING AS A POINTER"
              new_stack_index = target_element.parent.elements_array.index(target_element)
              switch_to_container_stack(new_container_stack, new_stack_index + 1)
            else
              new_stack_index = divert.target.split(".").last.to_i
              switch_to_container_stack(new_container_stack, new_stack_index)
              return noop(new_container_stack, new_stack_index)
            end
          end
        end
      else
        puts "#{print_padding}NOT RUNNING DIVERT"
        return :divert_not_taken
      end
    end

    def run_embedded_engine(target)
      target_container = engine.navigate_from(container_stack.container, target)

      emedded_call_stack = CallStack.new(target_container.stack, state, engine, @debug_padding+1)

      embedded_engine = Engine.new(state, engine.story, emedded_call_stack)
      puts "#{print_padding}RUN EMBEDDED ENGINE⏳"
      embedded_engine.step

      if embedded_engine.current_text.empty? && !emedded_call_stack.evaluation_stack.stack.empty?
        evaluation_stack.push(emedded_call_stack.evaluation_stack.pop)
      else
        evaluation_stack.push(embedded_engine.current_text)
      end
    end

    def next_sequence_shuffle_index
      number_of_elements = evaluation_stack.pop

      sequence_container = container_stack

      sequence_count = evaluation_stack.pop

      loop_index = sequence_count / number_of_elements

      iteration_index = sequence_count % number_of_elements

      # debugger
      sequence_path = state.current_pointer# container_stack.container.path_string

      seed = sequence_path.each_codepoint.sum + state.randomizer_seed

      randomizer = Random.new(seed)
      unpicked_indicies = (0..(number_of_elements-1)).to_a

      puts ({
        # test_sequence: test_sequence,
        number_of_elements: number_of_elements,
        sequence_count: sequence_count,
        loop_index: loop_index,
        iteration_index: iteration_index,
        sequence_path: sequence_path,
        unpicked_indicies: unpicked_indicies,
        seed: seed,
        # result: returned_index,
      })

      # debugger if sequence_path == "f_shuffle.0"
      (0..iteration_index).to_a.each do |i|
        chosen = randomizer.rand(2147483647) % unpicked_indicies.size
        chosen_index = unpicked_indicies[chosen]
        puts "#{print_padding}\t#{{sequence_path: sequence_path, seed: seed, unpicked_indicies: unpicked_indicies, chosen: chosen, chosen_index: chosen_index, iteration_index: iteration_index, i: i}}"
        # debugger if sequence_path == "f_shuffle.0"
        unpicked_indicies.delete(chosen)

        if i == iteration_index
          return chosen_index
        end
        puts "#{print_padding}\t🐧"
      end

      test_sequence = 4.times.map{randomizer.rand(number_of_elements)}
      returned_index = randomizer.rand(number_of_elements)

      puts ({
        test_sequence: test_sequence,
        number_of_elements: number_of_elements,
        sequence_count: sequence_count,
        loop_index: loop_index,
        iteration_index: iteration_index,
        sequence_path: sequence_path,
        seed: seed,
        result: returned_index,
      })

      x = ["one", "two"]
      # debugger

      return returned_index
    end

    def run_divert?(divert)
      run_divert = true
      if divert.is_conditional?
        puts "#{print_padding}DIVERT CHECK:"
        boolean_value = evaluation_stack.pop
        puts "#{print_padding}DIVERT CHECK: #{boolean_value}"
        if boolean_value.nil?
          puts "#{print_padding} IS NULL"
          raise Error, "conditional check hit a nil value"
        end
        run_divert = false if boolean_value == 0
      end

      run_divert
    end

    def add_choice?(choice)
      run_choice = true

      if choice.is_invisible_default?
        puts "#{print_padding}INVISIBLE DEFAULT"
        return false
      end

      if choice.once_only? && visits_for_current_container > 1
        puts "#{print_padding}ONCE ONLY, ALREADY VISITED"
        return false
      end

      if choice.has_condition?
        puts "#{print_padding}CHOICE CHECK:"
        boolean_value = evaluation_stack.pop
        run_choice = false if boolean_value == 0
        puts "#{print_padding}CHOICE CHECK: #{boolean_value} #{run_choice}"
      end

      run_choice
    end

    def switch_to_container_stack(new_container_stack, new_stack_index)
      puts "#{print_padding}SWITCHING TO NEW STACK INLINE"
      puts "#{print_padding}#{{stack: new_container_stack.container.path_string, index: new_stack_index}}"
      @container_stack = new_container_stack
      @current_stack_index = new_stack_index
    end

    def new_container_stack_empty?(new_container_stack)
      new_container_stack.elements.empty?
    end
  end

  class EvaluationStack
    include ControlCommands

    attr_accessor :stack, :string_evaluation_mode_stack, :mode

    def initialize(debug_padding = 0)
      @debug_padding = debug_padding + 1
      puts "#{print_padding}===NEW EVAL STACK==="
      self.stack = []
      self.string_evaluation_mode_stack = []
      self.mode = :evaluation_mode
    end

    def clone_attributes
      {
        stack: stack.dup,
        string_evaluation_mode_stack: string_evaluation_mode_stack.dup,
        mode: mode.dup
      }
    end

    def rebuild_from_attributes(attributes)
      self.stack = attributes[:stack]
      self.string_evaluation_mode_stack = attributes[:string_evaluation_mode_stack]
      self.mode = attributes[:mode]
    end

    def print_padding
      return "" if @debug_padding <= 0
      "#{'  ' * @debug_padding}==>"
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
        puts "#{print_padding}PUSH STR BEFORE -> #{value}: #{self.string_evaluation_mode_stack.inspect}"
        self.string_evaluation_mode_stack.unshift(value)
        puts "#{print_padding}PUSH STR AFTER: #{self.string_evaluation_mode_stack.inspect}"
      else
        puts "#{print_padding}PUSH BEFORE -> #{value}: #{self.stack.inspect}"
        self.stack.unshift(value)
        puts "#{print_padding}PUSH AFTER: #{self.stack.inspect}"
      end
    end

    def pop
      if string_evaluation_mode?
        puts "#{print_padding}POP STR BEFORE: #{self.string_evaluation_mode_stack.inspect}"
        x = self.string_evaluation_mode_stack.shift
        puts "#{print_padding}POP STR AFTER: #{self.string_evaluation_mode_stack.inspect}"
        x
      else
        puts "#{print_padding}POP BEFORE: #{self.stack.inspect}"
        x = self.stack.shift
        puts "#{print_padding}POP AFTER: #{self.stack.inspect}"
        x
      end
    end

    def duplicate_topmost
      puts "#{print_padding}DUP BEFORE: #{self.stack.inspect}"
      x = push(topmost.dup)
      puts "#{print_padding}DUP AFTER: #{self.stack.inspect}"
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