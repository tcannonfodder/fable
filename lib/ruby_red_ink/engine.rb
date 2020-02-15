module RubyRedInk
  class Engine
    attr_accessor :state, :story, :call_stacks, :current_call_stack, :named_container_pool, :output_stream

    def initialize(state, story)
      self.state = state
      self.story = story
      build_named_container_pool
      process_global_declaration
      self.call_stacks = [CallStack.new(story.root.stack, state, self)]
      self.current_call_stack = call_stacks.first
      self.output_stream = StringIO.new
    end

    def step
      return nil if current_call_stack.nil?

      stack_output = current_call_stack.step
      value_from_stack = stack_output[:element]
      self.current_pointer = stack_output[:path]

      case stack_output[:action]
      when :new_callstack
        new_callstack = CallStack.new(value_from_stack, state, self)
        call_stacks << new_callstack
        self.current_call_stack = new_callstack
        return step
      when :tunnel, :standard_divert
        tunnel_divert = value_from_stack
        target_container = named_container_pool[tunnel_divert.target]
        if target_container.nil?
          target_container = Path.navigate(story.root, current_call_stack.container_stack.container, tunnel_divert.target)
        end
        puts "-----"
        new_callstack = CallStack.new(target_container.stack, state, self)
        call_stacks << new_callstack
        self.current_call_stack = new_callstack
        return step
      when :pop_stack
        call_stacks.delete(current_call_stack)
        self.current_call_stack = call_stacks.last
        return step
      when :glue
        # Seeking back 1 character allows us to
        # remove the newline from the stream
        output_stream.seek(-1, IO::SEEK_END)
        return step
      when :noop, :pop
        return step
      when :output
        output_stream << value_from_stack
        return step
      end
    end

    def navigate_from(container, path_string)
      Path.navigate(story.root, container, path_string)
    end

    def current_text
      output_stream.rewind
      output_stream.read.gsub(/\n{2,}/,"\n")
    end

    def current_pointer=(value)
      state.current_pointer = value
    end

    def current_pointer
      state.current_pointer
    end

    def process_global_declaration
      return nil if !story.global_declaration
      global_declaration = story.global_declaration
      self.output_stream = StringIO.new
      self.call_stacks = [CallStack.new(global_declaration.stack, state, self)]
      self.current_call_stack = call_stacks.first

      step_value = step

      while !step_value.nil?
        step_value = step
      end
    end

    def build_named_container_pool
      self.named_container_pool = {}

      add_to_named_container_pool(story.root)
    end

    def add_to_named_container_pool(container)
      named_container_pool.merge!(container.all_named_containers)

      container.stack.elements.select{|x| x.is_a?(Container)}.each do |container|
        add_to_named_container_pool(container)
      end
    end
  end
end