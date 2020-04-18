module RubyRedInk
  class CallStack
    attr_accessor :threads, :thread_counter, :start_of_root

    def initialize(story_context_or_call_stack)
      if story_context_or_call_stack.is_a?(Story)
        start_of_root = Pointer.start_of(story_context_or_call_stack.root_content_container)
        reset!
      elsif story_context_or_call_stack.is_a?(CallStack)
        call_stack_to_copy = story_context_or_call_stack
        self.threads = []

        call_stack_to_copy.threads.each do |thread|
          self.threads << thread.copy
        end

        self.thread_container = call_stack_to_copy.thread_counter
        self.start_of_root = call_stack_to_copy.start_of_root
      end
    end

    def reset!
      new_thread = Thread.new
      new_thread.call_stack << Element.new(:tunnel, self.start_of_root)
      self.threads = [new_thread]
      self.thread_counter = 0
    end

    def elements
      call_stack
    end

    def depth
      elements.size
    end

    def current_element
      thread = threads.last
      thread.call_stack.last
    end

    def current_element_index
      call_stack.size - 1
    end

    def current_thread
      threads.last
    end

    def can_pop_thread?
      threads.size > 1 && !element_is_evaluate_from_game?
    end

    def element_is_evaluate_from_game?
      current_element.type == :function_evaluation_from_game
    end

    def push(type, options = {external_evaluation_stack_height: 0, output_stream_length_when_pushed: 0})
      # When pushing to callstack, maintain the current content path, but jump
      # out of expressions by default
      element = Element.new(type, current_element.current_pointer, in_expression_evaluation: false)

      element.evaluation_stack_height_when_pushed = options[:external_evaluation_stack_height]
      element.function_start_in_output_stream = options[:output_stream_length_when_pushed]

      call_stack << element
    end

    def can_pop?(type = nil)
      return false if call_stack.size <= 1
      return true if type.nil?
      return current_element.type == type
    end

    def pop!(type=nil)
      if can_pop?(type)
        call_stack.pop
      else
        raise Error, "Mismatched push/pop in Callstack"
      end
    end

    # Get variable value, dereferencing a variable pointer if necessary
    def get_temporary_variable_with_name(name, context_index = -1)
      if context_index == -1
        context_index = current_element_index + 1
      end

      context_element = call_stack[context_index - 1]

      return context_element.temporary_variables[name]
    end

    def set_temporary_variable(name, value, declare_new, context_index = -1)
      if context_index == -1
        context_index = current_element_index + 1
      end

      context_element = call_stack[context_index - 1]

      if !declare_new && !context_element.temporary_variables.has_key?(name)
        raise Error, "Could not find temporary variable to set: #{name}"
      end

      if context_element.temporary_variables.has_key?(name)
        old_value = context_element.temporary_variables[name]
        ListValue.retain_list_origins_for_assignment(old_value, value)
      end

      context_element.temporary_variables[name] = value
    end

    # Find the most appropriate context for this variable. Are we referencing
    # a temporary or global variable? Note that the compiler will have warned
    # us about possible conflicts, so anything that happens here should be safe
    def context_for_variable_named(name)
      # Current temporary context?
      # (Shouldn't attempt to access contexts higher in the callstack)
      if current_element.temporary_variables.has_key?(name)
        return current_element_index + 1
      else
        # Global
        return 0
      end
    end

    def thread_with_index(index)
      threads.find{|thread| thread.thread_index == index}
    end

    def call_stack
      current_thread.call_stack
    end

    def push_thread!
      new_thread = current_thread.copy
      self.thread_counter += 1
      self.threads << new_thread
    end

    def fork_thread!
      forked_thread = current_thread.copy
      self.thread_counter += 1
      forked_thread.thread_index = self.thread_counter

      return forked_thread
    end

    def pop_thread!
      if can_pop_thread?
        threads.delete(current_thread)
      else
        raise Error, "Can't pop thread"
      end
    end

    def from_hash!(hash_to_use, story_context)
      self.threads = []

      hash_to_use["threads"].each do |thread_object|
        self.threads << Thread.new(thread_object, story_context)
      end

      self.thread_counter = hash_to_use["threadCounter"]
      self.start_of_root = Pointer.start_of(story_context.root_content_container)
    end

    def to_hash
      export = {}
      export["threads"] = []
      self.threads.each do |thread|
        export["threads"] << thread.to_hash
      end

      export["threadCounter"] = self.thread_counter
      export
    end

    def call_stack_trace
      result = StringIO.new

      self.threads.each_with_index do |thread, i|
        is_current_thread = thread == current_thread

        result << "=== THREAD #{i}/#{threads.count} #{'(current)' if is_current_thread }\n"

        thread.call_stack.each do |element|
          case element.type
          when :function
            result << "  [FUNCTION] "
          when :tunnel
            result << "  [TUNNEL] "
          end

          pointer = element.current_pointer
          if !pointer.null_pointer?
            result << "<SOMEWHERE IN #{pointer.container.path.to_s}>\n"
          end
        end
      end

      result.rewind
      result.read
    end

    class Element
      attr_accessor :current_pointer, :in_expression_evaluation,
      :temporary_variables, :type

      alias_method :in_expression_evaluation?, :in_expression_evaluation

      # When this callstack element is actually a function evaluation called
      # from the game, we need to keep track of when it was called so that
      # we know whether there was any return value
      attr_accessor :evaluation_stack_height_when_pushed

      # When functions are called, we trim whitespace from the start & end of
      # what they generate, so we make sure we know where the function's
      # start/end are
      attr_accessor :function_start_in_output_stream

      def initialize(type, pointer, options = {in_expression_evaluation: false})
        self.current_pointer = pointer
        self.in_expression_evaluation = options[:in_expression_evaluation]
        self.temporary_variables = {}
        self.type = type
      end

      def copy
        copied_element = self.class.new(type, pointer, in_expression_evaluation: in_expression_evaluation)
        copied_element.temporary_variables = temporary_variables.dup
        copied_element.evaluation_stack_height_when_pushed = evaluation_stack_height_when_pushed
        copied_element.function_start_in_output_stream = function_start_in_output_stream
        copied_element
      end
    end

    class Thread
      attr_accessor :call_stack, :thread_index, :previous_pointer


      def initialize(**arguments)
        self.previous_pointer = Pointer.null_pointer

        if arguments.size == 0
          self.call_stack = []
        else
          self.initialize_with_thread_object_and_story_context(arguments[0], arguments[1])
        end
      end

      def initialize_with_thread_object_and_story_context(thread_object, story_context)
        self.call_stack = []
        self.thread_index = thread_object["threadIndex"]

        thread_object["callstack"].each do |element|
          type = PushPopType::TYPE_LOOKUP[element["type"]]
          pointer = Pointer.null_pointer

          current_container_path_string = element["cPath"]

          if current_container_path_string
            thread_pointer_result = story_context.content_at_path(Path.new(current_container_path_string))
            pointer.container = thread_pointer_result.container
            pointer.index = element["idx"]

            if thread_pointer_result.object.nil?
              raise Error, "When loading state, internal story location couldn't be found: #{current_container_path_string}. Has the story changed since this save data was created?"
            elsif thread_pointer_result.approximate?
              story_context.warning("When loading state, internal story location couldn't be found: #{current_container_path_string}, so it wa approximated to #{pointer.container.path.to_s} to recover. Has the story changed since this save data was created?")
            end
          end

          in_expression_evaluation = element["exp"]

          new_element = Element.new(type, pointer, in_expression_evaluation)

          if element["temp"]
            new_element.temporary_variables = Serializer.convert_to_runtime_objects_hash(element["temp"])
          else
            new_element.temporary_variables = {}
          end

          self.call_stack << new_element
        end

        if thread_object["previousContentObject"]
          previous_path = Path.new(thread_object["previousContentObject"])
          self.previous_pointer = story_context.pointer_at_path(previous_path)
        end
      end

      def copy
        copied_thread = self.class.new
        copied_thread.thread_index = thread_index
        self.call_stack.each do |element|
          copied_thread.call_stack << element.copy
        end

        copied_thread.previous_pointer = previous_pointer
        copied_thread
      end

      def to_hash
        export = {}

        export["callstack"] = []

        call_stack.each do |element|
          element_export = {}
          if !element.current_pointer.null_pointer?
            element_export["cPath"] = element.current_pointer.container.path.to_s
            element_export["idx"] = element.current_pointer.index
          end

          element_export["exp"] = element.in_expression_evaluation?
          element_export["type"] = PushPopType::TYPES[self.type]

          if element.temporary_variables.any?
            element_export["temp"] = element.temporary_variables.dup
          end

          export["call_stack"] << element_export
        end

        export["threadIndex"] = thread_index

        if !previous_pointer.null_pointer?
          export["previousContentObject"] = self.previous_pointer.resolve!.path.to_s
        end

        export
      end
    end
  end
end