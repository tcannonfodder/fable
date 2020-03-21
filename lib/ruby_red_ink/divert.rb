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
        target_path = nil
      else
        target_path = Path.new(value)
      end
    end

    def has_variable_target?
      !variable_divert_name.nil?
    end
  end
end