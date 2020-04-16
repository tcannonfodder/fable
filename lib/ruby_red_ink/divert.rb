module RubyRedInk
  class Divert < RuntimeObject
    attr_accessor :target_path, :target_pointer,
    :variable_divert_name, :pushes_to_stack, :stack_push_type, :is_external,
    :external_arguments, :is_conditional

    alias_method :pushes_to_stack?, :pushes_to_stack
    alias_method :is_external?, :is_external
    alias_method :is_conditional?, :is_conditional

    def target_path
      # Resolve any relative paths to global paths as we come across them
      if !@target_path.nil? && @target_path.relative?
        target_object = target_pointer.resolve!
        if !target_pointer.nil?
          @target_path = target_object.path
        end
      end

      return @target_path
    end

    def target_path=(value)
      @target_path = value
      @target_pointer = Pointer.null_pointer
    end

    def target_pointer
      if @target_pointer.null_pointer?
        target_object = resolve_path(@target_path).object

        if @target_path.last_component.is_index?
          @target_pointer.container = target_object.parent
          @target_pointer.index = @target_path.last_component.index
        else
          @target_pointer = Pointer.start_of(target_object)
        end
      end

      return @target_pointer
    end

    def target_path_string
      return nil if target_path.nil?

      return compact_path_string(target_path)
    end

    def target_path_string=(value)
      if value.nil?
        self.target_path = nil
      else
        self.target_path = Path.new(value)
      end
    end

    def ==(other_divert)
      if !other_divert.nil?
        if self.has_variable_target? == other_divert.has_variable_target?
          if self.has_variable_target?
            return self.variable_divert_name == other_divert.variable_divert_name
          else
            return self.target_path == other_divert.target_path
          end
        end
      end
      return false
    end

    def has_variable_target?
      !variable_divert_name.nil?
    end

    def to_s
      if has_variable_target?
        return "Divert(variable: #{variable_divert_name})"
      elsif target_path.nil?
        return "Divert(null"
      else
        result = ""

        target_string = target_path.to_s
        target_line_number = debug_line_number_of_path(target_path)
        if !target_line_number.nil?
          target_string = "line #{target_line_number}"
        end

        push_type = ""
        if pushes_to_stack?
          if stack_push_type == :FUNCTION
            push_type = " function"
          else
            push_type = " tunnel"
          end
        end

        "Divert#{'?' if is_conditional?}#{push_type} -> #{target_path_string} (#{target_string})"
      end
    end
  end
end