module RubyRedInk
  class Story < RuntimeObject
    class CannotContinueError < Error ; end


    CURRENT_INK_VERSION = 19
    MINIMUM_COMPATIBLE_INK_VERSION = 18

    attr_accessor :original_object, :state, :profiler,
      :list_definitions, :main_content_container,
      :allow_external_function_fallbacks

    def initialize(original_object)
      self.original_object = original_object
      self.state = StoryState.new(self)

      correct_ink_version?

      if original_object["root"].nil?
        raise ArgumentError, "no root object in ink"
      end

      @recursive_content_count = 0

      if !original_object["listDefs"].empty?
        self.list_definitions = Serializer.convert_to_list_definitions(original_object["listDefs"])
      else
        self.list_definitions = Serializer.convert_to_list_definitions({})
      end
      self.main_content_container = Serializer.convert_to_runtime_object(original_object["root"])

      reset_state!
    end

    def continue(&block)
      internal_continue(&block)
      return current_text
    end

    def continue_maximially(&block)
      result = StringIO.new
      while can_continue?
        result << continue
      end

      result.rewind
      return result.read
    end

    def current_choices
      return self.state.current_choices
    end

    def current_text
      return self.state.current_text
    end

    def current_tags
      return self.state.current_tags
    end

    def current_errors
      return self.state.current_errors
    end

    def current_warnings
      return self.state.current_warnings
    end

    def has_errors?
      current_errors.any?
    end

    def has_warnings?
      current_warnings.any?
    end

    def can_continue?
      state.can_continue?
    end

    def ink_version
      original_object["inkVersion"]
    end

    def start_profiling
      self.profiler = Profiler.new
    end

    def stop_profiling
      self.profiler = nil
    end

    def profile?
      !self.profiler.nil?
    end

    def global_declaration
      self.main_content_container.named_content["global decl"]
    end

    def reset_state!
      self.state = StoryState.new(self)
      reset_globals!
    end

    def reset_errors!
      state.reset_errors!
    end

    def reset_callstack!
      state.force_end!
    end

    def reset_globals!
      if !global_declaration.nil?
        original_pointer = state.current_pointer
        choose_path(Path.new("global decl"), {incrementing_turn_index: false})

        internal_continue
        state.current_pointer = original_pointer
      end

      self.state.variables_state.snapshot_default_globals
    end

    def content_at_path(path)
      main_content_container.content_at_path(path)
    end

    def knot_container_with_name(name)
      main_content_container.named_content[name]
    end

    def pointer_at_path(path)
      return Pointer.null_pointer if path.empty?

      path_length_to_use = path.length
      if path.components.last.is_index?
        path_length_to_use = path.length - 1
        result = main_content_container.content_at_path(path, partial_path_start: 0, partial_path_length: path_length_to_use)
        new_pointer_container = result.container
        new_pointer_index = path.components.last.index
        new_pointer = Pointer.new(new_pointer_container, new_pointer_index)
      else
        result = main_content_container.content_at_path(path)
        new_pointer = Pointer.new(result.container, -1)
      end

      if result.object.nil? || (result.object == main_content_container && path_length_to_use > 0)
        raise StoryError, "Failed to find content at path '#{path.components_string}', and no approximation was possible."
      elsif result.approximate?
        warning("Failed to find content at path '#{path.components_string}', so it was approximated to '#{result.object.path.components_string}'")
      end

      return new_pointer
    end

    # Maximum Snapshot stack:
    # - @state_snapshot_during_save -- not retained, but returned to game code
    # - @state_snapshot_at_last_newline (has older patch)
    # - @state (current, being patched)
    def state_snapshot!
      @state_snapshot_at_last_newline = self.state
      self.state = state.copy_and_start_patching!
    end

    def restore_state_snapshot!
      # Patched state had temporarily hijacked our variables_state and
      # set its own callstack on it, so we need to restore that
      # If we're in the middle of saving, we may also need to give the
      # variables_state the old patch

      @state_snapshot_at_last_newline.restore_after_patch!
      self.state = @state_snapshot_at_last_newline
      @state_snapshot_at_last_newline = nil
    end

    def discard_snapshot!
      @state_snapshot_at_last_newline = nil
    end

    def internal_continue(&block)
      profiler.pre_continue! if profile?

      @recursive_content_count += 1

      if !can_continue?
        raise CannotContinueError, "make sure to check can_continue?"
      end

      state.did_safe_exit = false
      state.reset_output!

      output_stream_ends_in_newline = false

      while can_continue?
        begin
          output_stream_ends_in_newline = continue_single_step!
        rescue StoryError => e
          add_error!(e.message, {use_end_line_number: e.use_end_line_number?})
          break
        end

        break if output_stream_ends_in_newline
      end


      # 3 outcomes:
      # - got a newline (finished this line of text)
      # - can't continue (e.g: choices, or end of story)
      # - error

      if output_stream_ends_in_newline || !can_continue?
        # Do we need to rewind, because we evaluated further than we should?
        if !@state_snapshot_at_last_newline.nil?
          restore_state_snapshot!
        end

        # Finished this section of content, or reached a choice point
        if !can_continue?
          if state.callstack.can_pop_thread?
            add_error!("Thread available to pop, threads should always be flat by the end of evaluation?")
          end

          if state.generated_choices.empty? && !state.did_safe_exit? && @temporary_evaluation_container.nil?
            if state.callstack.can_pop?(:tunnel)
              add_error!("unexpectedly reached end of content. Do you need a '->->' to return from a tunnel?")
            elsif state.callstack.can_pop?(:function)
              add_error!("unexpectedly reached end of content. Do you need a '~ return'?")
            elsif state.callstack.can_pop?
              add_error!("ran out of content. Do you need a '-> DONE' or '-> END'?")
            else
              add_error!("unexpectedly reached end of content for unknown reason.")
            end
          end

          state.did_safe_exit = false

          if !block.nil?
            yield block
          end
        end
      end

      @recursive_content_count -= 1

      profiler.post_continue! if profile?
    end

    def continue_single_step!
      profiler.pre_step! if profile?

      step!

      profiler.post_step! if profile?

      if !can_continue? && state.callstack.element_is_evaluate_from_game?
        try_following_default_invisible_choice
      end

      profiler.pre_snapshot! if profile?

      # Don't save/rewind during string evaluation, which is a special state
      # used for choices
      if !state.in_string_evaluation?
        # we previously found a newline, but we're double-checking that it won't
        # be removed` by glue
        if !@state_snapshot_at_last_newline.nil?
          change = calculate_newline_output_state_change(
            @state_snapshot_at_last_newline.current_text, state.current_text,
            @state_snapshot_at_last_newline.current_tags.size, state.current_tags.size
          )

          # The last time we saw a newline, it was definitely the end of the
          # line, so we want to rewind to that point
          if change == :extended_beyond_newline
            restore_state_snapshot!

            # Hit a newline for sure, we're done
            return true
          end

          # Newline that previously existed is no longer value (eg: encountered glue)
          if change == :newline_removed
            discard_snapshot!
          end
        end

        # Current content ends in a newline - approaching end of our evaluation

        if state.output_stream_ends_in_newline?
          # If we can continue evaluation for a bit:
          # - create a snapshot in case we need to rewind
          # We're going to keep stepping in case we see glue or some
          # non-text content such as choices

          if can_continue?
            # Don't bother to record the state beyond the current newline
            # example:
            # e.g.:
            # Hello world\n            // record state at the end of here
            # ~ complexCalculation()   // don't actually need this unless it generates text

            if @state_snapshot_at_last_newline.nil?
              state_snapshot!
            end
          else
            # we're about to exit since we can't continue, make sure we don't
            # have an old state lying around
            discard_snapshot!
          end
        end
      end

      profiler.post_snapshot! if profile?

      return false
    end

    def step!
      should_add_to_stream = true

      # Get current content
      pointer = state.current_pointer
      return if pointer.null_pointer?


      # Step directly into the first element of content in a container (if necessary)
      container_to_enter = pointer.resolve!
      while container_to_enter.is_a?(Container)
        # Mark container as being entered
        visit_container!(container_to_enter, at_start: true)

        # no content? the most we can do is step past it
        break if container_to_enter.content.empty?

        pointer = Pointer.start_of(container_to_enter)
        container_to_enter = pointer.resolve!
      end

      state.current_pointer = pointer

      profiler.step!(state.callstack) if profile?
      # is the current content object:
      # - normal content
      # - or a logic/flow statement? If so, do it
      # Stop flow if we hit a stack pop when we're unable to pop
      # (e.g: return/done statement in knot that was diverted to
      # rather than called as a function)
      current_content_object = pointer.resolve!
      is_logic_or_flow_content = perform_logic_and_flow_control(current_content_object)

      # Has flow been forced to end by flow control above?
      if state.current_pointer.null_pointer?
        return
      end

      if is_logic_or_flow_content
        should_add_to_stream = false
      end

      # content to add to the evaluation stack or output stream
      if should_add_to_stream
        # If we're pushing a variable pointer onto the evaluation stack,
        # ensure that it's specific to our current (and possibly temporary)
        # context index. And make a copy of the pointer so that we're not
        # editing the original runtime object
        if current_content_object.is_a?(VariablePointerValue)
          variable_pointer = current_content_object
          if variable_pointer.context_index == -1
            # create a new object so we're not overwriting the story's own data
            context_index = state.callstack.context_for_variable_named(variable_pointer.variable_name)
            current_content_object = VariablePointerValue.new(variable_pointer.variable_name, context_index)
          end
        end

        # expression evaluation content
        if state.in_expression_evaluation?
          state.push_evaluation_stack(current_content_object)
        else
          # output stream content
          state.push_to_output_stream(current_content_object)
        end
      end

      # Increment the content pointer, following diverts if necessary
      next_content!

      # Starting a thread should be done after the increment to the
      # content pointer, so that when returning from the thread, it
      # returns to the content after this instruction
      if current_content_object.is_a?(ControlCommand) && current_content_object.command_type == :CLONE_THREAD
        state.callstack.push_thread!
      end
    end

    def visit_container!(container, options)
      at_start = options[:at_start]

      if !container.counting_at_start_only? || at_start
        if container.visits_should_be_counted?
          state.increment_visit_count_for_container!(container)
        end

        if container.turn_index_should_be_counted?
          state.record_turn_index_visit_to_container!(container)
        end
      end
    end

    def visit_changed_containers_due_to_divert
      previous_pointer = state.previous_pointer
      pointer = state.current_pointer

      # Unless we're pointing directly at a piece of content, we don't do
      # counting here. Otherwise, the main stepping function will do the
      # counting

      return if pointer.null_pointer? || pointer.index == -1

      # First, find the previously open set of containers
      @previous_containers = []
      if !previous_pointer.null_pointer?
        previous_ancestor = previous_pointer.resolve! || previous_pointer.container
        while !previous_ancestor.nil?
          @previous_containers << previous_ancestor
          previous_ancestor = previous_ancestor.parent
        end
      end

      # If the new object is a container itself, it will be visted
      # automatically at the next actual content step. However, we need to walk
      # up the new ancestry to see if there are more new containers
      current_child_of_container = pointer.resolve!

      return if current_child_of_container.nil?

      current_container_ancestor = current_child_of_container.parent

      all_children_entered_at_start = true
      while !current_container_ancestor.nil? && (!@previous_containers.include?(current_container_ancestor) || current_container_ancestor.counting_at_start_only?)
        # check whether this ancestor container is being entered at the start
        # by checking whether the child object is the first

        entering_at_start = (
          current_container_ancestor.content.size > 0 &&
          current_child_of_container == current_container_ancestor.content[0] &&
          all_children_entered_at_start
        )

        # Don't count it as entering at start if we're entering randomly
        # somewhere within a Container B that happens to be nexted at index 0
        # of Container A. It only counts if we're diverting directly to the
        # first leaf node

        all_children_entered_at_start = false if !entering_at_start

        # Mark a visit to this container
        visit_container!(current_container_ancestor, at_start: entering_at_start)

        current_child_of_container = current_container_ancestor
        current_container_ancestor = current_container_ancestor.parent
      end
    end

    def process_choice(choice_point)
      show_choice = true

      # don't create choice if it doesn't pass the conditional
      if choice_point.has_condition?
        condition_value = state.pop_evaluation_stack
        if !Value.truthy?(condition_value)
          show_choice = false
        end
      end

      start_text = ""
      choice_only_text = ""

      if choice_point.has_choice_only_content?
        choice_only_text = state.pop_evaluation_stack
      end

      if choice_point.has_start_content?
        start_text = state.pop_evaluation_stack
      end

      # Don't create the choice if the player has aready read this content
      if choice_point.once_only?
        if state.visit_count_for_container(choice_point.choice_target) > 0
          show_choice = false
        end
      end


      # We go through the whole process of creating the choice above so
      # that we consume the content for it, since otherwise it'll be
      # shown on the output stream
      return nil if !show_choice

      choice = Choice.new
      choice.target_path = choice_point.path_when_chosen
      choice.source_path = choice_point.path.to_s
      choice.invisible_default = choice_point.is_invisible_default?

      # We need to capture the state of the callstack at the point where
      # the choice was generated, since after the generation of this choice
      # we may go on to pop out from a tunnel (possible if the choice was
      # wrapped in a conditional), or we may pop out from a thread, at which
      # point that thread is discarded. Fork clones the thread, gives it a new
      # ID, but without affecting the thread stack itself
      choice.thread_at_generation = state.callstack.fork_thread!

      # set the final text for the choice
      choice.text = "#{start_text} #{choice_only_text}".strip

      return choice
    end

    def perform_logic_and_flow_control(element)
      return false if element.nil?

      # Divert
      if element.is_a?(Divert)
        if element.is_conditional?
          return true if !state.pop_evaluation_stack.truthy?
        end

        if element.has_variable_target?
          variable_name = element.target
          variable_value = state.variables_state.get_variable_with_name(variable_name)

          if variable_value.nil?
            add_error!("Tried to divert using a target from a variable that could not be found (#{variable_name})")
          elsif !variable_value.is_a?(DivertTargetValue)
            error_message = "Tried to divert to a target from a variable, but the variable (#{variable_name}) didn't contain a divert target, it "
            if variable_value.to_i == 0
              error_message += "was empty/null (the value 0)"
            else
              error_message == "was #{variable_value}"
            end

            add_error!(error_message)
          end

          state.diverted_pointer = pointer_at_path(element.target_path)
        elsif element.is_external?
          call_external_function(element.target, element.number_of_arguments)
          return true
        else
          state.diverted_pointer = pointer_at_path(element.target_path)
        end

        if element.pushes_to_stack?
          state.callstack.push(
            element.stack_push_type,
            output_stream_length_when_pushed: state.output_stream.count
          )
        end

        if state.diverted_pointer.nil? && !element.is_external?
          if element && element.debug_metadata.source_name
            add_error!("Divert target doesn't exist: #{element.debug_metadata.source_name}")
          else
            add_error!("Divert resolution failed: #{element}")
          end
        end

        return true
      end

      if element.is_a?(ControlCommand)
        case element.command_type
        when :EVALUATION_START
          assert!(!state.in_expression_evaluation?, "Already in expression evaluation?")
          state.in_expression_evaluation = true
        when :EVALUATION_END
          assert!(state.in_expression_evaluation?, "Not in expression evaluation mode")
          state.in_expression_evaluation = false
        when :EVALUATION_OUTPUT
          # if the expression turned out to be empty, there may not be
          # anything on the stack
          if state.evaluation_stack.size > 0
            output = state.pop_evaluation_stack
            if !output.is_a?(Void)
              state.push_to_output_stream(StringValue.new(output.to_s))
            end
          end
        when :NOOP
          :NOOP
        when :DUPLICATE_TOPMOST
          state.push_evaluation_stack(state.peek_evaluation_stack)
        when :POP_EVALUATED_VALUE
          state.pop_evaluation_stack
        when :POP_TUNNEL, :POP_FUNCTION
          # Tunnel onwards is allowed to specify an optional override divert
          # to go to immediately after returning: ->-> target
          override_tunnel_return_target = nil

          if element.command_type == :POP_TUNNEL
            pop_type = PushPopType::TYPES[:tunnel]
          elsif element.command_type == :POP_FUNCTION
            pop_type = PushPopType::TYPES[:function]
          end

          if pop_type == PushPopType::TYPES[:tunnel]
            override_tunnel_return_target = state.pop_evaluation_stack
            if !override_tunnel_return_target.is_a?(DivertTargetValue)
              assert!(override_tunnel_return_target.is_a?(Void), "Expected void if ->-> doesn't override target")
            end
          end

          if state.exit_function_evaluation_from_game?
            :NOOP
          elsif state.callstack.current_element.type != pop_type || !state.callstack.can_pop?
            types = {
              PushPopType::TYPES[:function] => "function return statement (~return)",
              PushPopType::TYPES[:tunnel] => "tunnel onwards statement (->->)"
            }

            expected = types[state.callstack.current_element.type]

            if !state.callstack.can_pop?
              expected = "end of flow (-> END or choice)"
            end

            add_error!("Found #{types[element]}, when expected #{expected}")
          else
            state.pop_callstack

            # does tunnel onwards override by diverting to a new ->-> target?
            if override_tunnel_return_target.is_a?(DivertTargetValue)
              state.diverted_pointer = pointer_at_path(override_tunnel_return_target.target_path)
            end
          end
        when :BEGIN_STRING_EVALUATION_MODE
          state.push_to_output_stream(element)
          assert!(state.in_expression_evaluation?, "Expected to be in an expression when evaluating a string")
          state.in_expression_evaluation = false
        when :END_STRING_EVALUATION_MODE
          content_stack_for_string = []
          item_from_output_stream = nil
          while !ControlCommand.is_instance_of?(item_from_output_stream, :BEGIN_STRING_EVALUATION_MODE)
            item_from_output_stream = state.pop_from_output_stream
            if item_from_output_stream.is_a?(StringValue)
              content_stack_for_string << item_from_output_stream
            end
          end

          #return to expression evaluation (from content mode)
          state.in_expression_evaluation = true
          state.push_evaluation_stack(StringValue.new(content_stack_for_string.reverse.join.to_s))
        when :PUSH_CHOICE_COUNT
          state.push_evaluation_stack(IntValue.new(state.generated_choices.size))
        when :TURNS
          state.push_evaluation_stack(IntValue.new(state.current_turn_index + 1))
        when :TURNS_SINCE, :READ_COUNT
          target = state.pop_evaluation_stack
          if !target.is_a?(DivertTargetValue)
            extra_note =""
            if value.is_a?(Numeric)
              extra_note = ". Did you accidentally pass a read count ('knot_name') instead of a target ('-> knot_name')?"
            end
            add_error("TURNS SINCE expected a divert target (knot, stitch, label name), but saw #{target}#{extra_note}")
          end

          container = content_at_path(target.target)

          if !container.nil?
            if element == :TURNS_SINCE
              count = state.turns_since_for_container(container)
            else
              count = state.visit_count_for_container(container)
            end
          else
            if element == :TURNS_SINCE
              count = -1 #turn count, default to never/unknown
            else
              count = 0 #visit count, assume 0 to default to allowing entry
            end

            warning("Failed to find container for #{element} lookup at #{target.target}")
          end

          state.push_evaluation_stack(IntValue.new(count))
        when :RANDOM
          max_int = state.pop_evaluation_stack
          min_int = state.pop_evaluation_stack

          if !min_int.is_a?(Numeric)
            add_error!("Invalid value for minimum parameter of RANDOM(min, max)")
          end

          if !max_int.is_a?(Numeric)
            add_error!("Invalid value for maximum parameter of RANDOM(min, max)")
          end

          if min_int > max_int
            add_error!("RANDOM was called with minimum as #{min_int} and maximum as #{max_int}. The maximum must be larger")
          end

          result_seed = state.story_seed + state.previous_random
          random = new Random(result_seed)

          next_random = random.rand(min_int, max_int)
          state.push_evaluation_stack(IntValue.new(next_random))
          # next random number, rather than keeping the random object around
          state.previous_random = next_random
        when :SEED_RANDOM
          seed = state.pop_evaluation_stack
          if seed.nil?
            error!("Invalid value passed to SEED_RANDOM")
          end

          # Story seed affects both RANDOM & shuffle behavior
          state.story_seed = seed
          state.previous_random = 0

          # SEED_RANDOM returns nothing
          state.push_evaluation_stack(Void)
        when :VISIT_INDEX
          count = state.visit_count_for_container(state.current_pointer.container) - 1
          state.push_evaluation_stack(IntValue.new(count))
        when :SEQUENCE_SHUFFLE_INDEX
          state.push_evaluation_stack(IntValue.new(next_sequence_shuffle_index))
        when :START_THREAD
          :NOOP #handled in main step function
        when :DONE
          # we may exist in the context of the initial act of creating
          # the thread, or in the context of evaluating the content
          if state.callstack.can_pop_thread?
            state.callstack.pop_thread!
          else
            # in normal flow, allow safe exit without warning
            state.did_safe_exit = true
            # stop flow in the current thread
            state.current_pointer = Pointer.null_pointer
          end
        when :STORY_END
          state.force_end!
        when :LIST_FROM_INT
          integer_value = state.pop_evaluation_stack
          list_name = state.pop_evaluation_stack

          if integer_value.nil?
            raise StoryError, "Passed non-integer when creating a list element from a numerical value."
          end

          if list_definitions[list_name]
            state.push_evaluation_stack(list_definitions[list_name][integer_value])
          else
            raise StoryError, "Failed to find LIST called #{list_name}"
          end
        when :LIST_RANGE
          max = state.pop_evaluation_stack
          min = state.pop_evaluation_stack
          target_list = state.pop_evaluation_stack

          if target_list.nil? || min.nil? || max.nil?
            raise StoryError, "Expected list, minimum, and maximum for LIST_RANGE"
          end

          stack.push_evaluation_stack(target_list.sublist(min, max))
        when :LIST_RANDOM
          list = state.pop_evaluation_stack

          if list.nil?
            raise StoryError, "Expected list for LIST_RANDOM"
          end

          # list was empty, return empty list
          if list.size == 0
            new_list = List.new
          else
            #non-empty source list
            result_seed = state.story_seed + state.previous_random
            random = new Random(result_seed)
            list_item_index = random.rand(0, list.size)

            random_item = list[list_item_index]

            # Origin list is simply the origin of the one element
            new_list = List.new(list.key.origin_name, self)
            new_list[random_item.key, random_item.value]

            state.previous_random = list_item_index
          end

          state.push_evaluation_stack(ListValue.new(new_list))
        else
          add_error!("unhandled Control Command #{element}")
        end

        return true
      end

      # variable handling
      case element
      when VariableAssignment
        state.variables_state.assign(element, state.pop_evaluation_stack)
        return true
      when VariableReference
        if !element.path_for_count.nil?
          count = state.visit_count_for_container(element.container_for_count)
          found_value = count
        else
          found_value = state.variables_state.get_variable_with_name(element.name)

          if found_value.nil?
            warning("Variable not found: '#{element.name}'. Using default value of 0 (false). This can happen with temporary variables if the declaration hasn't yet been hit. Globals are always given a default value on load if a value doesn't exist in the save state.");
            found_value = 0
          end
        end

        state.push_evaluation_stack(found_value)
        return true
      end

      if element.is_a?(NativeFunctionCall)
        parameters = []
        element.number_of_parameters.times{ parameters << state.pop_evaluation_stack }

        state.push_evaluation_stack(element.call!(parameters))
        return true
      end

      # no control content, so much be ordinary content
      return false
    end

    # Change the current position of the story to the given path. From here you can
    # call Continue() to evaluate the next line.
    #
    # The path string is a dot-separated path as used internally by the engine.
    # These examples should work:
    #
    #    myKnot
    #    myKnot.myStitch
    #
    # Note however that this won't necessarily work:
    #
    #    myKnot.myStitch.myLabelledChoice
    #
    # ...because of the way that content is nested within a weave structure.
    #
    # By default this will reset the callstack beforehand, which means that any
    # tunnels, threads or functions you were in at the time of calling will be
    # discarded. This is different from the behaviour of ChooseChoiceIndex, which
    # will always keep the callstack, since the choices are known to come from the
    # correct state, and known their source thread.
    #
    # You have the option of passing false to the resetCallstack parameter if you
    # don't want this behaviour, and will leave any active threads, tunnels or
    # function calls in-tact.
    #
    # This is potentially dangerous! If you're in the middle of a tunnel,
    # it'll redirect only the inner-most tunnel, meaning that when you tunnel-return
    # using '->->', it'll return to where you were before. This may be what you
    # want though. However, if you're in the middle of a function, ChoosePathString
    # will throw an exception.
    def choose_path_string(path_string, reset_callstack=true, arguments = [])
      if !on_choose_path_string.nil?
        on_choose_path_string(path_string, arguments)
      end

      if reset_callstack
        reset_callstack!
      else
        # choose_path_string is potentially dangerous since you can call it
        # when the stack is pretty much in any state. Let's catch one of the
        # worst offenders
        if state.callstack.current_element == :POP_FUNCTION
          container = state.callstack.current_element.current_pointer.container
          function_detail = ""
          if !container.nil?
            function_detail = "(#{container.path.to_s})"
          end

          raise StoryError("Story was running a function #{function_detail} when you called choose_path_string(#{path_string}) - this is almost certainly not not what you want! Full stack trace:\n#{state.callstack.callstack_trace}")
        end
      end

      state.pass_arguments_to_evaluation_stack(arguments)
      choose_path(Path.new(path_string))
    end

    def choose_path(path, incrementing_turn_index=true)
      state.set_chosen_path(path, incrementing_turn_index)

      # take note of newly visited containers for read counts, etc.
      visit_changed_containers_due_to_divert
    end

    # Chooses the Choice from the currentChoices list with the given
    # index. Internally, this sets the current content path to that
    # pointed to by the Choice, ready to continue story evaluation.
    def choose_choice_index(choice_index)
      choice_to_choose = current_choices[choice_index]
      assert!(!choice_to_choose.nil?, "choice out of range")

      # Replace callstack with the one from the thread at the choosing point,
      # so that we can jump into the right place in the flow.
      # This is important in case the flow was forked by a new thread, which
      # can create multiple leading edges for the story, each of which has its
      # own content
      if !on_make_choice.nil?
        on_make_choice(choice_to_choose)
      end

      state.callstack.current_thread = choice_to_choose.thread_at_generation

      choose_path(choice_to_choose.target_path)
    end

    def has_function?(function_name)
      !knot_container_with_name(function_name).nil?
    end

    # Evaluates a function defined in ink
    def evaluate_function(function_name, arguments = [])
      if !on_evaluate_function.nil?
        on_evaluate_function(function_name, arguments)
      end

      if function_name.to_s.strip.empty?
        raise StoryError, "Function is null, empty, or whitespace"
      end

      function_container = knot_container_with_name(function_name)
      if function_container.nil?
        raise StoryError, "Function does not exist: #{function_name}"
      end

      # Snapshot the output stream
      output_stream_before = state.output_stream.dup
      state.reset_output!

      # State will temporarily replace the callstack in order to evaluate
      state.start_function_evaluation_from_game!(function_container, arguments)

      # Evaluate the function, and collect the string output
      string_output = StringIO.new
      while can_continue
        string_output << continue
      end

      string_output.rewind

      text_output = string_output.read

      # Restore the output stream in case this was called during the main
      # Story Evaluation
      state.reset_output!(output_stream_before)

      # Finish evaluation, and see whether anything was produced
      result = state.complete_function_evaluation_from_game!

      if !on_complete_evaluate_function.nil?
        on_complete_evaluate_function(function_name, arguments, text_output, result)
      end

      return {
        result: result,
        text_output: text_output
      }
    end

    def call_external_function(function_name, number_of_arguments)
      function = external_functions[function_name]
      if function.nil?
        if allow_external_function_fallbacks?
          fallback_function_container = knot_container_with_name(function_name)
          if fallback_function_container.nil?
            raise StoryError, "Trying to call external function #{function_name} which has not been bound, and fallback ink function cannot be found"
          end

          # Divert directly into the fallback function and we're done
          state.callstack.push(:POP_FUNCTION, output_stream_length_when_pushed: state.output_stream.count)
          state.diverted_pointer = Pointer.start_of(fallback_function_container)
          return
        end
      else
        raise StoryError, "Trying to call EXTERNAL function #{function_name}, which has not been defined (and ink fallbacks disabled)"
      end

      arguments = []
      number_of_arguments.times{ arguments << state.pop_evaluation_stack }

      arguments.reverse!

      # Run the function
      result = function(**arguments)

      if result.nil?
        result = Void
      else
        result = Value.parse(result)
        if result.nil?
          raise StoryError, "Could not create ink value from returned object of type #{result.class}"
        end
      end

      state.push_evaluation_stack(result)
    end

    def bind_external_function(function_name, external_function)
      if external_functions.has_key?(function_name)
        raise StoryError, "Function #{function_name} has already been bound."
      end

      external_functions[function_name] = external_function
    end

    def unbind_external_function(function_name)
      if !external_functions.has_key?(function_name)
        raise StoryError, "Function #{function_name} has not been bound."
      end

      external_functions.delete(function_name)
    end

    # Check that all EXTERNAL ink functions have a valid function.
    # Note that this will automatically be called on the first call to continue
    def validate_external_bindings!
      missing_externals = missing_external_bindings(main_content_container)

      has_validated_externals = true

      if missing_externals.empty?
        return true
      else
        add_error!("ERROR: Missing function binding for the following: #{missing_externals.join(", ")}, #{allow_external_function_fallbacks? ? 'and no fallback ink functions found' : '(ink fallbacks disabled)'}")
      end
    end

    def missing_external_bindings(container)
      missing_externals = Set.new
      container.content.each do |item|
        if item.is_a?(Container)
          missing_externals.merge(missing_external_bindings(item))
          return missing_externals
        end

        if item.is_a?(ExternalFunctionDivert)
          if allow_external_function_fallbacks?
            fallback_found = main_content_container.named_content.has_key?(item.target)
            if !fallback_found
              missing_externals << item.target
            end
          else
            missing_externals << item.target
          end
        end
      end

      container.named_content.each do |key, container|
        missing_externals.merge(missing_external_bindings(container))
      end

      return missing_externals
    end

    def calculate_newline_output_state_change(previous_text, current_text, previous_tag_count, current_tag_count)
      newline_still_exists = (current_text.size >= previous_text.size) && (current_text[previous_text.size - 1] == "\n")

      if ((previous_tag_count == current_tag_count) &&(previous_text.size == current_text.size) && newline_still_exists)
        return :no_change
      end

      if !newline_still_exists
        return :newline_removed
      end

      if current_tag_count > previous_tag_count
        return :extended_beyond_newline
      end

      if !current_text[previous_text.size..].strip.empty?
        return :extended_beyond_newline
      end

      # There's new text, but it's just whitespace, so there's still potential
      # for glue to kill the newline
      return :no_change
    end

    def global_tags
      tags_at_start_of_flow_container_with_path_string("")
    end

    def tags_for_content_at_path(path)
      tags_at_start_of_flow_container_with_path_string(path)
    end

    def tags_at_start_of_flow_container_with_path_string(path_string)
      path = Path.new(path_string)

      flow_container = content_at_path(path).container

      while true
        first_content = flow_container.content.first
        if first_content.is_a?(Container)
          flow_container = first_content
        else
          break
        end
      end

      return content.tags
    end

    # Useful when debugging a (very short) story, to visualise the state of the
    # story. Add this call as a watch and open the extended text. A left-arrow mark
    # will denote the current point of the story.
    # It's only recommended that this is used on very short debug stories, since
    # it can end up generate a large quantity of text otherwise.
    def build_string_of_hierarchy
      return main_content_container.build_string_of_hierarchy(0, state.current_pointer.resolve!)
    end

    def build_string_of_container(container)
      container.build_string_of_hierarchy(0, state.current_pointer.resolve!)
    end

    def next_content!
      # setting previousContentObject is critical for visit_changed_containers_due_to_divert
      state.previous_pointer = state.current_pointer

      # Divert step?
      if !state.diverted_pointer.null_pointer?
        state.current_pointer = state.diverted_pointer
        state.diverted_pointer = Pointer.null_pointer

        # Internally uses state.previous_content_object and state.current_content_object
        visit_changed_containers_due_to_divert

        # Diverted location has valid content?
        if !state.current_pointer.null_pointer?
          return
        end

        # Otherwise, if diverted located doesn't have valid content,
        # Drop down and attempt to increment
        # This can happenm if the diverted path is intentionally jumping
        # to the end of a container - e.g: a Conditional that's re-joining
      end

      successful_pointer_increment = increment_content_pointer

      # Ran out of content? Try to auto-exit from a function, or
      # finish evaluating the content of a thread
      if !successful_pointer_increment
        did_pop = false

        if state.callstack.can_pop?(:function)
          # Pop from the call stack
          state.callstack.pop_callstack(:function)

          # This pop was due to dropping off the end of a function that didn't
          # return anything, so in this case we make sure the evaluator has
          # something to chomp on if it needs it

          if state.in_expression_evaluation?
            state.push_evaluation_stack(Void)
          end

          did_pop = true
        elsif state.callstack.can_pop_thread?
          state.callstack.pop_thread!
          did_pop = true
        else
          state.exit_function_evaluation_from_game?
        end

        # Step past the point where we last called out
        if did_pop && !state.current_pointer.null_pointer?
          next_content!
        end
      end
    end

    def increment_content_pointer
      successful_increment = true

      pointer = state.callstack.current_element.current_pointer
      pointer.index += 1

      # Each time we step off the end, we fall out to the next container, all the
      # time we're in indexed rather than named content
      while pointer.index >= pointer.container.content.size
        successful_increment = false

        next_ancestor = pointer.container.parent
        break if !next_ancestor.is_a?(Container)

        index_in_ancestor = next_ancestor.content.index(pointer.container)
        break if index_in_ancestor == -1

        pointer = Pointer.new(next_ancestor, index_in_ancestor)

        # Increment to the next content in outer container
        pointer.index += 1
        successful_increment = true
      end

      pointer = Pointer.null_pointer if !successful_increment

      state.callstack.current_element.current_pointer = pointer
      return successful_increment
    end

    def try_following_default_invisible_choice
      all_choices = state.current_choices

      # Is a default invisible choice the ONLY choice?
      invisible_choices = all_choices.select{|choice| choice.invisible_default?}
      if invisible_choices.empty? || all_choices.size > invisible_choices.size
        return false
      end

      choice = invisible_choices[0]

      # Invisible choice may have been generate on a different thread, in which
      # case we need to restore it before we continue
      state.callstack.current_thread = choice.thread_at_generation

      # If there's a chance that this state will be rolled back before the
      # invisible choice then make sure that the choice thread is left intact,
      # and it isn't re-entered in an old state
      if !state_snapshot_at_last_newline.nil?
        state.callstack.current_thread = state.callstack.fork_thread!
      end

      choose_path(choice.target_path, incrementing_turn_index: false)

      return true
    end


    def next_sequence_shuffle_index
      number_of_elements = state.pop_evaluation_stack
      if !number_of_elements.is_a?(Numeric)
        error!("Expected number of elements in sequence for shuffle index")
        return 0
      end

      sequence_container = state.current_pointer.container

      sequence_count = state.pop_evaluation_stack
      loop_index = sequence_count / number_of_elements
      iteration_index = sequence_count % number_of_elements

      # Generate the same shuffle based on
      # - the hash of this container, to make sure it's consistent
      # - How many times the runtime has looped around this full shuffle
      sequence_hash = sequence_container.path.to_s.bytes.sum

      randomizer_seed = sequence_hash + loop_index + state.story_seed
      randomizer = Random.new(randomizer_seed)
      unpicked_indicies = (0..(number_of_elements-1)).to_a

      (0..iteration_index).to_a.each do |i|
        chosen = randomizer.rand(2147483647) % unpicked_indicies.size
        chosen_index = unpicked_indicies[chosen]
        unpicked_indicies.delete(chosen)

        if i == iteration_index
          return chosen_index
        end
      end

      raise StoryError, "Should never reach here"
    end

    def error!(message, options = {use_end_line_number: false})
      exception = StoryError.new(message)
      e.use_end_line_number = options[:use_end_line_number]
      raise e
    end

    def warning(message)
      add_error!(message, is_warning: true)
    end

    def add_error!(message, options = {is_warning: false, use_end_line_number: false})
      debug_metadata = current_debug_metadata

      error_type_string = options[:is_warning] ? "WARNING" : "ERROR"

      if !debug_metadata.nil?
        line_number = options[:use_end_line_number] ? debug_metadata.end_line_number : debug_metadata.start_line_number
        message = "RUNTIME #{error_type_string}: '#{debug_metadata.file_name}' line #{line_number}: #{message}"
      elsif !state.current_pointer.null_pointer?
        message = "RUNTIME #{error_type_string}: (#{state.current_pointer.path}) #{message}"
      else
        message = "RUNTIME #{error_type_string}: #{message}"
      end

      state.add_error(message, is_warning: options[:is_warning])

      # In a broken state, we don't need to know about any other errors
      if !options[:is_warning]
        state.force_end!
      end
    end

    def assert!(condition, message = nil)
      if !condition
        if message.nil?
          message = "Story assert"
        end

        throw new StoryError, "#{message} #{current_debug_metadata}"
      end
    end

    def current_debug_metadata
      pointer = state.current_pointer

      if !pointer.null_pointer?
        debug_metadata = pointer.resolve!.debug_metadata
        return debug_metadata if !debug_metadata.nil?
      end

      # Move up callstack if possible
      state.callstack.elements.each do |element|
        pointer = element.current_pointer
        if !pointer.null_pointer? && pointer.resolve! != nil
          debug_metadata = pointer.resolve!.debug_metadata
          return debug_metadata if !debug_metadata.nil?
        end
      end

      # Current/previous path may not be valid if we're just had an error, or
      # if we've simply run out of content. As a last resort, try to grab
      # something from the output stream
      state.output_stream.each do |item|
        return item.debug_metadata if !item.debug_metadata.nil?
      end

      return nil
    end

    def current_line_number
      debug_metadata = current_debug_metadata
      return 0 if debug_metadata.nil?
      return debug_metadata.start_line_number
    end

    def correct_ink_version?
      if ink_version.nil?
        raise ArgumentError, "No ink vesion provided!"
      end

      if ink_version > CURRENT_INK_VERSION
        raise ArgumentError, "Version of ink (#{ink_version}) is greater than what the engine supports (#{CURRENT_INK_VERSION})"
      end

      if ink_version < CURRENT_INK_VERSION
        raise ArgumentError, "Version of ink (#{ink_version}) is less than what the engine supports (#{CURRENT_INK_VERSION})"
      end

      if ink_version != CURRENT_INK_VERSION
        puts "WARNING: Version of ink (#{ink_version}) doesn't match engine's version (#{CURRENT_INK_VERSION})"
      end

      true
    end
  end
end