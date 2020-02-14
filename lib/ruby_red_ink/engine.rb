module RubyRedInk
  class Engine
    attr_accessor :state, :story, :call_stacks, :current_call_stack

    def initialize(state, story)
      self.state = state
      self.story = story
      self.call_stacks = [CallStack.new(story.root.stack, state)]
      self.current_call_stack = call_stacks.first
    end

    def step
      return nil if current_call_stack.nil?

      stack_output = current_call_stack.step
      value_from_stack = stack_output[:element]
      self.current_pointer = stack_output[:path]

      case stack_output[:action]
      when :new_callstack
        new_callstack = CallStack.new(value_from_stack, state)
        call_stacks << new_callstack
        self.current_call_stack = new_callstack
        return nil
      when :pop_stack
        call_stacks.delete(current_call_stack)
        self.current_call_stack = call_stacks.last
        return value_from_stack
      when :output
        return value_from_stack
      end
    end

    def current_pointer=(value)
      state.current_pointer = value
    end

    def current_pointer
      state.current_pointer
    end
  end
end