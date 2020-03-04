module RubyRedInk
  class Story
    class CannotContinueError < Error ; end


    CURRENT_INK_VERSION = 19
    MINIMUM_COMPATIBLE_INK_VERSION = 18

    attr_accessor :original_object, :state. :profiler,
      :list_definitions, :main_content_container,

    def initialize(original_object)
      self.original_object = original_object
      self.state = StoryState.new

      correct_ink_version?

      if original_object["root"].nil?
        raise ArgumentError, "no root object in ink"
      end

      @recursive_content_count = 0

      process_list_definitions!
      self.main_content_container = Container.new(original_object["root"], nil)

      reset_state!
    end

    def continue(&block)
      internal_continue(block)
      return current_text
    end

    def continue_maximially(&block)
      raise NotImplementedError
    end

    def current_choices
      raise NotImplementedError
    end

    def current_text
      raise NotImplementedError
    end

    def current_tags
      raise NotImplementedError
    end

    def current_errors
      raise NotImplementedError
    end

    def current_warnings
      raise NotImplementedError
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

    def global_variables
      state.global_variables
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
      root.nested_containers["global decl"]
    end

    def reset_state!
      self.state = StoryState.new
    end

    def reset_errors!
      state.reset_errors!
    end

    def reset_callstack!
      state.force_end!
    end

    def reset_globals!
      if global_declaration?
        original_pointer = state.current_pointer

        choose_path(Path.new("global decl"), {incrementing_turn_index: false})

        internal_continue

        state.current_pointer = original_pointer
      end

      global_variables.snapshot_default_globals!
    end

    def content_at_path(path)
      main_content_container.content_at_path(path)
    end

    def knot_container_with_name(name)
      main_content_container.named_content[name]
    end

    def pointer_at_path(path)
      return Pointer.null_pointer if path.empty?

      new_pointer = Pointer.new

      path_length_to_use = path.length

      if path.components.last.is_index?
        path_length_to_use = path.length - 1
        result = main_content_container.content_at_path(path, partial_path_length: path_length_to_use)
        new_pointer.container = result.container
        new_pointer.index - path.components.last.index
      else
        result = main_content_container.content_at_path(path)
        new_pointer.container = result.container
        new_pointer.index = -1
      end

      if result.object.nil? || (result.object == main_content_container && path_length_to_use > 0)
        raise StoryError, "Failed to find content at path '#{path.components_string}', and no approximation was possible."
      elsif result.approximate?
        add_warning!("Failed to find content at path '#{path.components_string}', so it was approximated to '#{result.object.path.components_string}'")
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

    protected

    def continue_internal(&block)
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
          if state.call_stack.can_pop_thread?
            add_error!("Thread available to pop, threads should always be flat by the end of evaluation?")
          end

          if state.generated_choices.empty? && !state.did_safe_exit? && @temporary_evaluation_container.nil?
            if state.call_stack.can_pop?(:tunnel)
              add_error!("unexpectedly reached end of content. Do you need a '->->' to return from a tunnel?")
            elsif state.call_stack.can_pop?(:function)
              add_error!("unexpectedly reached end of content. Do you need a '~ return'?")
            elsif state.call_stack.can_pop?
              add_error!("ran out of content. Do you need a '-> DONE' or '-> END'?")
            else
              add_error!("unexpectedly reached end of content for unknown reason.")
            end
          end

          state.did_safe_exit = false

          if !block.nil?
            yield &block
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

      if !can_continue? && state.call_stack.element_is_evaluate_from_game?
        try_following_default_invisible_choice!
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
      while !container_to_enter.nil?
        # Mark container as being entered
        visit_container!(container_to_enter, at_start: true)

        # no content? the most we can do is step past it
        break if container_to_enter.content.empty?

        pointer = Pointer.start_of(container_to_enter)
        container_to_enter = pointer.resolve!
      end

      state.current_pointer = pointer

      profiler.step!(state.call_stack) if profile?

      # is the current content object:
      # - normal content
      # - or a logic/flow statement? If so, do it
      # Stop flow if we hit a stack pop when we're unable to pop
      # (e.g: return/done statement in knot that was diverted to
      # rather than called as a function)
      current_content_object = pointer.resolve!

      is_logic_or_flow_content = perform_logic_and_flow_control!(current_content_object)

      # Has flow been forced to end by flow control above?
      return if state.current_pointer.null_pointer?

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
            context_index = state.call_stack.context_for_variable_named(variable_pointer.variable_name)
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
      if ControlCommands.get_control_command(value) == :CLONE_THREAD
        state.call_stack.push_thread!
      end
    end

    def visit_container!(contianer, options)
      at_start = options[:at_start]

      if !container.counting_start_only? || at_start
        if container.count_vists?
          state.increment_visit_count_for_container!(container)
        end

        if container.count_turn_index?
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

      currnet_container_ancestor = current_child_of_container.parent

      all_children_entered_at_start = true
      while !currnet_container_ancestor.nil? && (!@previous_containers.include?(currnet_container_ancestor) || currnet_container_ancestor.counting_start_only?)
        # check whether this ancestor container is being entered at the start
        # by checking whether the child object is the first

        entering_at_start = (
          current_container_ancestor.content.size > 0 &&
          current_child_of_container == currnet_container_ancestor.content[0] &&
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
        condition_value = state.pop_evaluation_stack!
        if !Value.truthy?(condition_value)
          show_choice = false
        end
      end

      start_text = ""
      choice_only_text = ""

      if choice_point.has_choice_only_content?
        choice_only_text = state.pop_evaluation_stack!
      end

      if choice_point.has_start_content?
        start_text = state.pop_evaluation_stack!
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
      choice.source_path = choice_point.path.as_string
      choice.invisible_default = choice_point.is_invisible_default?

      # We need to capture the state of the callstack at the point where
      # the choice was generated, since after the generation of this choice
      # we may go on to pop out from a tunnel (possible if the choice was
      # wrapped in a conditional), or we may pop out from a thread, at which
      # point that thread is discarded. Fork clones the thread, gives it a new
      # ID, but without affecting the thread stack itself
      choice.thread_at_generation = state.call_stack.fork_thread!

      # set the final text for the choice
      choice.text = "#{start_text} #{choice_only_text}".strip

      return choice
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

    def process_list_definitions!
      return nil root_container["listDefs"].empty?
      raise NotImplementedError
      # self.list_definitions = 
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