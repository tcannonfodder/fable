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
      :current_tags, :output_stream_tags_dirty

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
      self.story_seed = Random.new(time_seed).rand(100)
      self.previous_random = 0

      self.current_choices = []

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
        return 0
      end

      if has_patch? && patch.get_visit_count(container)
        return patch.get_visit_count(container)
      end

      container_path_string = container.path.as_string
      return visit_counts[container_path_string] || 0
    end

    def increment_visit_count_for_container!(container)
      if has_patch?
        current_count = visit_count_for_container(container)
        patch.set_visit_count(container, current_count + 1)
        return
      end

      container_path_string = container.path.as_string
      count = (visit_counts[container_path_string] || 1)
      visit_counts[container_path_string] = count
    end

    def record_turn_index_visit_to_container!(container)
      if has_patch?
        path.set_turn_index(container, current_turn_index)
        return
      end

      container_path_string = container.path.as_string
      turn_indicies[container_path_string] = current_turn_index
    end

    def turns_since_for_container(container)
      if !container.turn_index_should_be_counted?
        story.add_error!("TURNS_SINCE() for target (#{container.name}) - on #{container.debug_metadata}) unknown.")
      end

      if has_patch? && patch.get_turn_index(container)
        return (current_turn_index - patch.get_turn_index(container))
      end

      container_path_string = container.path.as_string

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
        return current_pointer.path.as_string
      end
    end

    def current_pointer
      callstack.current_element.current_pointer
    end

    def current_pointer=(value)
      callstack.current_element.current_pointer = value
    end

    def previous_pointer
      callstack.current_element.previous_pointer
    end

    def previous_pointer=(value)
      callstack.current_element.previous_pointer = value
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
      cleaned_string = ""

      string.each_line(chomp: true) do |line|
        cleaned_string += line.strip.gsub(MULTIPLE_WHITESPACE_REGEX, ' ')
      end

      cleaned_string
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

      copy.current_choices += self.current_choices

      if has_error?
        copy.current_errors = []
        copy.current_errors += self.current_errors
      end

      if has_warning?
        copy.current_warnings = []
        copy.current_warnings += self.current_warnings
      end

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
        self.visit_counts[container.path.as_string] = new_count
      end

      patch.turn_indicies.each do |container, new_count|
        self.turn_indicies[container.path.as_string] = new_count
      end
    end

    def reset_errors!
      self.current_errors = nil
      self.current_warnings = nil
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
        lines = try_splitting_head_tail_whitespace(object)
        lines.each do |line|
          push_item_to_output_stream(line)
        end

        output_stream_dirty!
        return
      end

      push_item_to_output_stream(object)
      output_stream_dirty!
    end

    def pop_from_output_stream(count)
      output_stream.pop(count)
      output_stream_dirty!
    end

    # Exports the current state to a hash that can be serialized in
    # the JSON format
    def to_hash
      result = {}

      has_choice_threads = false

      self.current_choices.each do |choice|
        choice.original_thread_index = choice.thread_at_generation.thread_index
        if callstack.thread_with_index(c.original_thread_index).nil?
          if !has_choice_threads
            has_choice_threads = true
            result["choiceThreads"]= {}
          end

          result["choiceThreads"][choice.original_thread_index.to_s] = choice.thread_at_generation.to_hash
        end
      end

      result["callstackThreads"] = callstack.to_hash
      result["variablesState"] = variables_state.to_hash
      result["evalStack"] = Serializer.convert_runtime_objects(self.evaluation_stack)
      result["outputStream"] = Serializer.convert_runtime_objects(self.output_stream)
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

      result["inkFormatVersion"] = Story.CURRENT_INK_VERSION

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

      self.callstack.from_hash!(loaded["callstackThreads"], story)
      self.variables_state.from_hash!(loaded["variablesState"])

      self.evaluation_stack = Serializer.convert_to_runtime_objects(loaded_state["evalStack"])
      self.output_stream = Serializer.convert_to_runtime_objects(loaded_state["outputStream"])
      self.output_stream_dirty!

      self.current_choices = Serializer.convert_to_choices(loaded_state["current_choices"])

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
          c.thread_at_generation = CallStack::Thread.new(saved_choice_thread, story)
        end
      end
    end
  end
end