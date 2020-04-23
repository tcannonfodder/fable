module RubyRedInk
  # All story state information is included in the StoryState class,
  # including global variables, read counts, the pointer to the current
  # point in the story, the call stack (for tunnels, functions, etc),
  # and a few other smaller bits and pieces. You can save the current
  # state using the serialization functions
  class StoryState
    CURRENT_INK_SAVE_STATE_VERSION = 8
    MINIMUM_COMPATIBLE_INK_LOAD_VERSION = 8

    MULTIPLE_WHITESPACE_REGEX = /[ \t]{2,}/

    attr_accessor :patch, :output_stream, :current_choices,
      :current_errors, :current_warnings, :callstack,
      :evaluation_stack, :diverted_pointer,
      :current_turn_index, :story_seed, :previous_random,
      :did_safe_exit, :story, :variables_state,
      :current_text, :output_stream_text_dirty,
      :current_tags, :output_stream_tags_dirty,
      :visit_counts, :turn_indicies

    alias_method :did_safe_exit?, :did_safe_exit

    def initialize(story)
      self.story = story
      self.output_stream = []
      self.output_stream_dirty!

      self.evaluation_stack = []

      self.callstack = CallStack.new(story)
      self.variables_state = VariablesState.new(callstack, story.list_definitions)

      self.visit_counts = {}
      self.turn_indicies = {}

      self.current_turn_index = -1

      # Seed the shuffle random numbers
      time_seed = Time.now.to_r * 1_000.0
      self.story_seed = IntValue.new(Random.new(time_seed).rand(100))
      self.previous_random = 0

      self.current_choices = []

      self.diverted_pointer = Pointer.null_pointer
      self.current_pointer = Pointer.null_pointer

      self.go_to_start!
    end

    # <summary>
    # Gets the visit/read count of a particular Container at the given path.
    # For a knot or stitch, that path string will be in the form:
    #
    #     knot
    #     knot.stitch
    #
    # </summary>
    # <returns>The number of times the specific knot or stitch has
    # been enountered by the ink engine.</returns>
    # <param name="pathString">The dot-separated path string of
    # the specific knot or stitch.</param>
    def visit_count_at_path_string(path_string)
      if has_patch?
        container = story.content_at_path(Path.new(path_string)).container
        if container.nil?
          raise Error, "Content at path not found: #{path_string}"
        end

        if patch.get_visit_count(container)
          return patch.get_visit_count(container)
        end
      end

      return visit_counts[path_string] || 0
    end

    def visit_count_for_container(container)
      if !container.visits_should_be_counted?
        story.add_error!("Read count for target (#{container.name} - on #{container.debug_metadata}) unknown.")
        return IntValue.new(0)
      end

      if has_patch? && patch.get_visit_count(container)
        return IntValue.new(patch.get_visit_count(container))
      end

      container_path_string = container.path.to_s
      return IntValue.new(visit_counts[container_path_string] || 0)
    end

    def increment_visit_count_for_container!(container)
      if has_patch?
        current_count = visit_count_for_container(container)
        patch.set_visit_count(container, current_count.value + 1)
        return
      end

      container_path_string = container.path.to_s
      count = (visit_counts[container_path_string] || 0)
      count += 1
      visit_counts[container_path_string] = count
    end

    def record_turn_index_visit_to_container!(container)
      if has_patch?
        patch.set_turn_index(container, current_turn_index)
        return
      end

      container_path_string = container.path.to_s
      turn_indicies[container_path_string] = current_turn_index
    end

    def turns_since_for_container(container)
      if !container.turn_index_should_be_counted?
        story.add_error!("TURNS_SINCE() for target (#{container.name}) - on #{container.debug_metadata}) unknown.")
      end

      if has_patch? && patch.get_turn_index(container)
        return (current_turn_index - patch.get_turn_index(container))
      end

      container_path_string = container.path.to_s

      if turn_indicies[container_path_string]
        return current_turn_index - turn_indicies[container_path_string]
      else
        return -1
      end
    end

    def callstack_depth
      callstack.depth
    end

    def current_choices
      # If we can continue generating text content rather than choices,
      # then we reflect the choice list as being empty, since choices
      # should always come at the end.
      return [] if can_continue?
      return @current_choices
    end

    def generated_choices
      return @current_choices
    end

    def current_path_string
      if current_pointer.null_pointer?
        return nil
      else
        return current_pointer.path.to_s
      end
    end

    def current_pointer
      callstack.current_element.current_pointer
    end

    def current_pointer=(value)
      callstack.current_element.current_pointer = value
    end

    def previous_pointer
      callstack.current_thread.previous_pointer
    end

    def previous_pointer=(value)
      callstack.current_thread.previous_pointer = value
    end

    def can_continue?
      !current_pointer.null_pointer? && !has_error?
    end

    def has_error?
      !current_errors.nil? && current_errors.size > 0
    end

    def has_warning?
      !current_warnings.nil? && current_warnings.size > 0
    end

    def current_text
      if @output_stream_text_dirty
        text_content = output_stream.select{|x| x.is_a?(StringValue)}.map(&:value).join

        @current_text = clean_output_whitespace(text_content)
        @output_stream_text_dirty = false
      end

      return @current_text
    end

    def current_tags
      if @output_stream_tags_dirty
        @current_tags = output_stream.select{|x| x.is_a?(Tag)}.map(&:text)
        @output_stream_tags_dirty = false
      end

      return @current_tags
    end

    def in_expression_evaluation?
      callstack.current_element.in_expression_evaluation?
    end

    def in_expression_evaluation=(value)
      callstack.current_element.in_expression_evaluation = value
    end

    def in_string_evaluation?
      @output_stream.reverse_each.any? do |item|
        item.is_a?(ControlCommand) && item.command_type == :BEGIN_STRING_EVALUATION_MODE
      end
    end

    def push_evaluation_stack(object)
      # include metadata about the origin List for list values when they're used
      # so that lower-level functions can make sure of the origin list to get
      # Related items, or make comparisons with integer values
      if object.is_a?(ListValue)
        # Update origin when list has something to indicate the list origin
        raw_list = object.value
        if !raw_list.origin_names.nil?
          if raw_list.origins.nil?
            raw_list.origins = []
          end

          raw_list.origins.clear

          raw_list.origin_names.each do |name|
            list_definition = story.list_definitions.find_list(name)
            if !raw_list.origins.include?(list_definition)
              raw_list.origins << list_definition
            end
          end
        end
      end

      evaluation_stack << object
    end

    def pop_evaluation_stack(number_of_items = nil)
      if number_of_items.nil?
        return evaluation_stack.pop
      end

      if number_of_items > evaluation_stack.size
        raise Error, "trying to pop too many objects"
      end

      return evaluation_stack.pop(number_of_items)
    end

    def peek_evaluation_stack
      return evaluation_stack.last
    end


    # <summary>
    # Ends the current ink flow, unwrapping the callstack but without
    # affecting any variables. Useful if the ink is (say) in the middle
    # a nested tunnel, and you want it to reset so that you can divert
    # elsewhere using choose_path_string. Otherwise, after finishing
    # the content you diverted to, it would continue where it left off.
    # Calling this is equivalent to calling -> END in ink.
    # </summary>
    def force_end!
      callstack.reset!
      @current_choices.clear
      self.current_pointer = Pointer.null_pointer
      self.previous_pointer = Pointer.null_pointer
      self.did_safe_exit = true
    end

    # At the end of a function call, trim any whitespace from the end.
    # We always trim the start and end of the text that a function produces.
    # The start whitespace is discard as it is generated, and the end
    # whitespace is trimmed in one go here when we pop the function.
    def trim_whitespace_from_function_end!
      assert!(callstack.current_element.type == PushPopType::TYPES[:function])

      function_start_point = callstack.current_element.function_start_in_output_stream

      # if the start point has become -1, it means that some non-whitespace
      # text has been pushed, so it's safe to go as far back as we're able
      if function_start_point == -1
        function_start_point = 0
      end

      i = @output_stream.count - 1

      # Trim whitespace from END of function call
      while i >= function_start_point
        object = output_stream[i]
        break if object.is_a?(ControlCommand)
        next if !object.is_a?(StringValue)

        if object.is_newline? || object.is_inline_whitespace?
          @output_stream.delete_at(i)
          output_stream_dirty!
        else
          break
        end

        i -= 1
      end
    end

    def pop_callstack(pop_type=nil)
      # At the end of a function call, trim any whitespace from the end
      if callstack.current_element.type == PushPopType::TYPES[:function]
        trim_whitespace_from_function_end!
      end

      callstack.pop!(pop_type)
    end

    def pass_arguments_to_evaluation_stack(arguments)
      if !arguments.nil?
        arguments.each do |argument|
          if !(argument.is_a?(Numeric) || argument.is_a?(String) || argument.is_a?(InkList))
            raise ArgumentError, "ink arguments when calling evaluate_function/choose_path_string_with_parameters must be int, float, string, or InkList. Argument was #{argument.class.to_s}"
          end

          push_evaluation_stack(Value.create(argument))
        end
      end
    end

    def start_function_evaluation_from_game(function_container, arguments)
      callstack.push(PushPopType::TYPES[:function_evaluation_from_game], output_stream_length_when_pushed: evaluation_stack.size)
      callstack.current_element.current_pointer = Pointer.start_of(function_container)
      pass_arguments_to_evaluation_stack(arguments)
    end

    def exit_function_evaluation_from_game?
      if callstack.current_element.type == PushPopType::TYPES[:function_evaluation_from_game]
        self.current_pointer = Pointer.null_pointer
        self.did_safe_exit = true
        return true
      end

      return false
    end

    def complete_function_evaluation_from_game
      if callstack.current_element.type != PushPopType::TYPES[:function_evaluation_from_game]
        raise Error, "Expected external function evaluation to be complete. Stack trace: #{callstack.call_stack_trace}"
      end

      original_evaluation_stack_height = callstack.current_element.evaluation_stack_height_when_pushed

      # do we have a returned value?
      # Potentially pop multiple values off the stack, in case we need to clean up after ourselves
      # (e.g: caller of evaluate_function may have passed too many arguments, and we currently have no way
      # to check for that)
      returned_object = nil
      while evaluation_stack.size > original_evaluation_stack_height
        popped_object = pop_evaluation_stack
        if returned_object.nil?
          returned_object = popped_object
        end
      end

      # Finally, pop the external function evaluation
      pop_callstack(PushPopType::TYPES[:function_evaluation_from_game])

      # What did we get back?
      if !returned_object.nil?
        if returned_object.is_a?(Void)
          return nil
        end

        # DivertTargets get returned as the string of components
        # (rather than a Path, which isn't public)
        if returned_object.is_a?(DivertTargetValue)
          return returned_object.value_object.to_s
        end

        # Other types can just have their exact object type.
        # VariablePointers get returned as strings.
        return returned_object.value_object
      end

      return nil
    end

    def output_stream_dirty!
      @output_stream_text_dirty = true
      @output_stream_tags_dirty = true
    end

    def go_to_start!
      callstack.current_element.current_pointer = Pointer.start_of(story.main_content_container)
    end

    # Cleans inline whitespace in the following way:
    # - Removes all whitespace from the start/end of line (including just before an \n)
    # - Turns all consecutive tabs & space runs into single spaces (HTML-style)
    def clean_output_whitespace(string)
      x = ""

      current_whitespace_start = -1
      start_of_line = 0

      string.each_char.with_index do |character, i|
        is_inline_whitespace = (character == " " || character == "\t")

        if is_inline_whitespace && current_whitespace_start == -1
          current_whitespace_start = i
        end

        if !is_inline_whitespace
          if(character != "\n" && (current_whitespace_start > 0) && current_whitespace_start != start_of_line)
            x += " "
          end

          current_whitespace_start = -1
        end

        if character == "\n"
          start_of_line = i + 1
        end

        if !is_inline_whitespace
          x << character
        end
      end

      return x

      # x = string.each_line(chomp: true).map do |line|
      #   if line.empty?
      #     nil
      #   else
      #     line.strip.gsub(MULTIPLE_WHITESPACE_REGEX, ' ') + "\n"
      #   end
      # end
      # cleaned_string = x.compact.join("\n")

      # cleaned_string
    end

    def has_patch?
      !patch.nil?
    end


    # WARNING: Any RuntimeObject content referenced within the StoryState will be
    # re-referenced rather than cloned. This is generally okay though, since
    # RuntimeObjects are treated as immutable after they've been set up.
    # (eg: We don't edit a StringValue after it's been created and added)
    def copy_and_start_patching!
      copy = self.class.new(story)
      copy.patch = StatePatch.new(self.patch)

      copy.output_stream += self.output_stream
      copy.output_stream_dirty!

      copy.current_choices += @current_choices
      if has_error?
        copy.current_errors = []
        copy.current_errors += self.current_errors
      end

      if has_warning?
        copy.current_warnings = []
        copy.current_warnings += self.current_warnings
      end

      copy.callstack = CallStack.new(story).from_hash!(self.callstack.to_hash, story)
      # reference copoy- exactly the same variable state!
      # we're expected not to read it only while in patch mode
      # (though the callstack will be modified)
      copy.variables_state = self.variables_state
      copy.variables_state.callstack = copy.callstack
      copy.variables_state.patch = copy.patch

      copy.evaluation_stack += self.evaluation_stack

      if !self.diverted_pointer.null_pointer?
        copy.diverted_pointer = self.diverted_pointer
      end

      copy.previous_pointer = self.previous_pointer

      # Visit counts & turn indicies will be read-only, not modified
      # while in patch mode
      copy.visit_counts = self.visit_counts
      copy.turn_indicies = self.turn_indicies

      copy.current_turn_index = self.current_turn_index
      copy.story_seed = self.story_seed
      copy.previous_random = self.previous_random

      copy.did_safe_exit = self.did_safe_exit

      return copy
    end

    def restore_after_patch!
      # VariablesState was being borrowed by the patched state, so restore it
      # with our own callstack. patch will be nil normally, but if you're in the
      # middle of a save, it may contain a patch for save purposes
      variables_state.callstack = callstack
      variables_state.patch = self.patch
    end

    def apply_any_patch!
      return if self.patch.nil?

      variables_state.apply_patch!

      patch.visit_counts.each do |container, new_count|
        self.visit_counts[container.path.to_s] = new_count
      end

      patch.turn_indicies.each do |container, new_count|
        self.turn_indicies[container.path.to_s] = new_count
      end
    end

    def reset_errors!
      self.current_errors = nil
      self.current_warnings = nil
    end

    def add_error(message, options = {is_warning: false})
      if !options[:is_warning]
        self.current_errors ||= []
        self.current_errors << message
      else
        self.current_warnings ||= []
        self.current_warnings << message
      end

      puts current_errors.inspect
      puts current_warnings.inspect
    end

    def reset_output!(objects_to_add = nil)
      self.output_stream = []
      if !objects_to_add.nil?
        self.output_stream += objects_to_add
      end

      output_stream_dirty!
    end

    def push_to_output_stream(object)
      if object.is_a?(StringValue)
        lines = try_splitting_head_tail_whitespace(object.value)
        if !lines.nil?
          lines.each do |line|
            push_item_to_output_stream(line)
          end

          output_stream_dirty!
          return
        end
      end

      push_item_to_output_stream(object)
      output_stream_dirty!
    end

    def pop_from_output_stream
      results = output_stream.pop
      output_stream_dirty!
      return results
    end

    def push_item_to_output_stream(object)
      include_in_output = true

      case object
      when Glue
        # new glue, so chomp away any whitespace from the end of the stream
        trim_newlines_from_output_stream!
        include_in_output = true
      when StringValue
        # New text: do we really want to append it, if it's whitespace?
        # Two different reasons for whitespace to be thrown away:
        # - Function start/end trimming
        # - User defined glue: <>
        # We also need to know when to stop trimming, when there's no whitespace

        # where does the current function call begin?
        function_trim_index = -1
        current_element = callstack.current_element
        if current_element.type == PushPopType::TYPES[:function]
          function_trim_index = current_element.function_start_in_output_stream
        end

        # Do 2 things:
        # - Find latest glue
        # - Check whether we're in the middle of string evaluation
        # If we're in string evaluation within the current function, we don't want to
        # trim back further than the length of the current string
        glue_trim_index = -1

        i = @output_stream.count - 1
        while i >= 0
          item_to_check = @output_stream[i]
          if item_to_check.is_a?(Glue)
            glue_trim_index = i
            break
          elsif ControlCommand.is_instance_of?(item_to_check, :BEGIN_STRING_EVALUATION_MODE)
            if i >= function_trim_index
              function_trim_index =  -1
            end
            break
          end

          i -= 1
        end

        # Where is the most aggresive (earliest) trim point?
        trim_index = -1
        if glue_trim_index != -1 && function_trim_index != -1
          trim_index = [glue_trim_index, function_trim_index].min
        elsif glue_trim_index != -1
          trim_index = glue_trim_index
        else
          trim_index = function_trim_index
        end

        # So, what are we trimming them?
        if trim_index != -1
          # While trimming, we want to throw all newlines away,
          # Whether due to glue, or start of a function
          if object.is_newline?
            include_in_output = false
          # Able to completely reset when normal text is pushed
          elsif object.is_nonwhitespace?
            if glue_trim_index > -1
              remove_existing_glue!
            end

            # Tell all functionms in callstack that we have seen proper text,
            # so trimming whitespace at the start is done
            if function_trim_index > -1
              callstack.elements.reverse_each do |element|
                if element.type == PushPopType::TYPES[:function]
                  element.function_start_in_output_stream = -1
                else
                  break
                end
              end
            end
          end
        # De-duplicate newlines, and don't ever lead with a newline
        elsif object.is_newline?
          if output_stream_ends_in_newline? || !output_stream_contains_content?
            include_in_output = false
          end
        end
      end

      if include_in_output
        @output_stream << object
        output_stream_dirty!
      end
    end

    # At both the start and the end of the string, split out the new lines like so:
    #
    #  "   \n  \n     \n  the string \n is awesome \n     \n     "
    #      ^-----------^                           ^-------^
    #
    # Excess newlines are converted into single newlines, and spaces discarded.
    # Outside spaces are significant and retained. "Interior" newlines within
    # the main string are ignored, since this is for the purpose of gluing only.
    #
    #  - If no splitting is necessary, null is returned.
    #  - A newline on its own is returned in a list for consistency.
    def try_splitting_head_tail_whitespace(string)
      head_first_newline_index = -1
      head_last_newline_index = -1

      string.each_char.each_with_index do |character, i|
        if character == "\n"
          if head_first_newline_index == -1
            head_first_newline_index = i
          end

          head_last_newline_index = i
        elsif character == " " || character == "\t"
          next
        else
          break
        end
      end

      tail_first_newline_index = -1
      tail_last_newline_index = -1
      string.reverse.each_char.each_with_index do |character, i|
        if character == "\n"
          if tail_last_newline_index == -1
            tail_last_newline_index = i
          end

          tail_first_newline_index = i
        elsif character == " " || character == "\t"
          next
        else
          break
        end
      end

      if head_first_newline_index == -1 && tail_last_newline_index == -1
        return nil
      end

      list_texts = []
      inner_string_start = 0
      inner_string_end = string.length

      if head_first_newline_index != -1
        if head_first_newline_index > 0
          leading_spaces = string[0, head_first_newline_index]
          list_texts << leading_spaces
        end

        list_texts << "\n"
        inner_string_start = head_last_newline_index + 1
      end

      if tail_last_newline_index != -1
        inner_string_end = tail_first_newline_index
      end

      if inner_string_end > inner_string_start
        inner_string_text = string[inner_string_start, (inner_string_end - inner_string_start)]
        list_texts << inner_string_text
      end

      if tail_last_newline_index != -1 && tail_first_newline_index > head_last_newline_index
        list_texts << "\n"
        if tail_last_newline_index < (string.length -1)
          number_of_spaces = (string.length - tail_last_newline_index) - 1
          trailing_spaces = string[tail_last_newline_index + 1, number_of_spaces]
          list_texts << trailing_spaces
        end
      end

      return list_texts.map{|x| StringValue.new(x) }
    end

    def trim_newlines_from_output_stream!
      remove_whitespace_from = -1

      # Work back from the end, and try to find the point where we need to
      # start removing content.
      #  - Simply work backwards to find the first newline in a string of whitespace
      # e.g. This is the content   \n   \n\n
      #                            ^---------^ whitespace to remove
      #                        ^--- first while loop stops here
      i = @output_stream.count - 1
      while i >= 0
        object = @output_stream[i]
        if object.is_a?(ControlCommand) || (object.is_a?(StringValue) && object.is_nonwhitespace?)
          break
        elsif object.is_a?(StringValue) && object.is_newline?
          remove_whitespace_from = i
        end

        i -= 1
      end

      # Remove the whitespace
      if remove_whitespace_from >= 0
        self.output_stream = self.output_stream[0..(remove_whitespace_from-1)]
      end

      output_stream_dirty!
    end

    # Only called when non-whitespace is appended
    def remove_existing_glue!
      @output_stream.each_with_index do |object, i|
        if object.is_a?(Glue)
          @output_stream.delete_at(i)
        elsif object.is_a?(ControlCommand)
        end
      end

      output_stream_dirty!
    end

    def output_stream_ends_in_newline?
      return false if @output_stream.empty?
      return @output_stream.last.is_a?(StringValue) && @output_stream.last.is_newline?
    end

    def output_stream_contains_content?
      @output_stream.any?{|x| x.is_a?(StringValue) }
    end

    # Exports the current state to a hash that can be serialized in
    # the JSON format
    def to_hash
      result = {}

      has_choice_threads = false

      self.current_choices.each do |choice|
        choice.original_thread_index = choice.thread_at_generation.thread_index
        if callstack.thread_with_index(choice.original_thread_index).nil?
          if !has_choice_threads
            has_choice_threads = true
            result["choiceThreads"]= {}
          end

          result["choiceThreads"][choice.original_thread_index.to_s] = choice.thread_at_generation.to_hash
        end
      end

      result["callstackThreads"] = callstack.to_hash
      result["variablesState"] = variables_state.to_hash
      result["evalStack"] = Serializer.convert_array_of_runtime_objects(self.evaluation_stack)
      result["outputStream"] = Serializer.convert_array_of_runtime_objects(self.output_stream)
      result["currentChoices"] = Serializer.convert_choices(@current_choices)

      if !self.diverted_pointer.null_pointer?
        result["currentDivertTarget"] = self.diverted_pointer.path.components_string
      end

      result["visitCounts"] = self.visit_counts
      result["turnIndicies"] = self.turn_indicies

      result["turnIdx"] = self.current_turn_index
      result["story_seed"] = self.story_seed
      result["previousRandom"] = self.previous_random

      result["inkSaveVersion"] = CURRENT_INK_SAVE_STATE_VERSION

      result["inkFormatVersion"] = Story::CURRENT_INK_VERSION

      return result
    end

    # Load a previously saved state from a Hash
    def from_hash!(loaded_state)
      if loaded_state["inkSaveVersion"].nil?
        raise Error, "ink save format incorrect, can't load."
      end

      if loaded_state["inkSaveVersion"] < MINIMUM_COMPATIBLE_INK_LOAD_VERSION
        raise Error, "Ink save format isn't compatible with the current version (saw #{loaded_state["inkSaveVersion"]}, but minimum is #{MINIMUM_COMPATIBLE_INK_LOAD_VERSION}), so can't load."
      end

      self.callstack.from_hash!(loaded_state["callstackThreads"], story)
      self.variables_state.from_hash!(loaded_state["variablesState"])

      self.evaluation_stack = Serializer.convert_to_runtime_objects(loaded_state["evalStack"])
      self.output_stream = Serializer.convert_to_runtime_objects(loaded_state["outputStream"])
      self.output_stream_dirty!

      self.current_choices = Serializer.convert_to_runtime_objects(loaded_state["currentChoices"])

      if loaded_state.has_key?("currentDivertTarget")
        divert_path = Path.new(loaded_state["currentDivertTarget"])
        self.diverted_pointer = story.pointer_at_path(divert_path)
      end

      self.visit_counts = loaded_state["visitCounts"]
      self.turn_indicies = loaded_state["turnIndicies"]

      self.current_turn_index = loaded_state["turnIdx"]
      self.story_seed = loaded_state["storySeed"]

      self.previous_random = loaded_state["previousRandom"] || 0


      saved_choice_threads = loaded_state["choiceThreads"] || {}

      @current_choices.each do |choice|
        found_active_thread = callstack.thread_with_index(choice.original_thread_index)
        if !found_active_thread.nil?
          choice.thread_at_generation = found_active_thread.copy
        else
          saved_choice_thread = saved_choice_threads[choice.original_thread_index.to_s]
          choice.thread_at_generation = CallStack::Thread.new(saved_choice_thread, story)
        end
      end
    end

    def assert!(condition, message=nil)
      story.assert!(condition, message)
    end

    # Don't make public since the method needs to be wrapped in a story for visit countind
    def set_chosen_path(path, incrementing_turn_index)
      # Changing direction, assume we need to clear current set of choices
      @current_choices.clear

      new_pointer = story.pointer_at_path(path)

      if !new_pointer.null_pointer? && new_pointer.index == -1
        new_pointer.index = 0
      end

      self.current_pointer = new_pointer

      if incrementing_turn_index
        self.current_turn_index += 1
      end
    end
  end
end