module RubyRedInk
  class CallStack

    def initialize(value = nil)
      @flag = value
    end

    def step
      @counter ||= 0

      return ControlCommands.get_control_command('done') if @counter > 3

      if @counter == 2 && @flag != :a
        new_call_stack = self.class.new(:a)
        @counter += 1
        return new_call_stack
      end

      return "#{@counter += 1}:#{@flag}"
    end
  end
end