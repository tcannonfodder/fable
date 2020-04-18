module RubyRedInk
  # Encompasses all the global variables in an ink Story, and
  # allows binding of a variable_changed event so that that game
  # code can be notified whenever the global variables change.
  class VariablesState
    attr_accessor :patch, :batch_observing_variable_changes,
      :changed_variables_for_batch_observing, :callstack,
      :globals, :list_definitions_origins, :variable_did_change_event,
      :default_global_variables

    def batch_observing_variable_changes=(value)
      @batch_observing_variable_changes = value
      if value
        @changed_variables_for_batch_observing = []

      # Finished observing variables in a batch, now send
      # notifications for changed variables all in one go
      else
        if @changed_variables_for_batch_observing != nil
          @changed_variables_for_batch_observing.uniq.each do |variable_name|
            current_value = @globals[variable_name]
            variable_changed_event(variable_name, current_value)
          end
        end

        @changed_variables_for_batch_observing = nil
      end
    end

    def [](variable_name)
      if !patch.nil? && patch.get_global(variable_name)
        return patch.get_global(variable_name).value_object
      end

      # Search main dictionary first
      # If it's not found, it might be because the story content has
      # changed, and the original default value hasn't been instantiated
      variable_value = @globals[variable_name] || @default_global_variables[variable_name]
      if !variable_value.nil?
        return variable_value.value_object
      else
        return nil
      end
    end

    def []=(variable_name, given_value)
      if !default_global_variables.has_key?(variable_name)
        raise Error, "Cannot assign to a variable (#{variable_name}) that hasn't been declared in the story"
      end

      value = Value.create(given_value)
      if value.nil?
        if given_value.nil?
          raise Error, "Cannot pass nil to VariableState"
        else
          raise Error, "Invalid value passed to VariableState: #{given_value}"
        end
      end

      set_global(variable_name, value)
    end

    def initialize(callstack, list_definitions_origins)
      self.globals = {}
      self.callstack = callstack
      self.list_definitions_origins = list_definitions_origins
      self.dont_save_default_values = true
    end

    def apply_patch!
      patch.globals.each do |name, value|
        self.globals[name] = value
      end

      if !changed_variables_for_batch_observing.nil?
        patch.changed_variables.each do |name|
          changed_variables_for_batch_observing << name
        end
      end

      patch = nil
    end

    def from_hash!(hash_to_use)
      @globals = {}
      @default_global_variables.each do |key, value|
        if hash_to_use.has_key?(key)
          @globals[key] = hash_to_use[key]
        else
          @globals[key] = value
        end
      end
    end

    # When saving out state, we can skip saving global values that
    # remain equal to the initial values that were declared in ink.
    # This makes the save object (potentially) much smaller assuming that
    # at least a portion of the globals haven't changed. However, it
    # can also take marginally longer to save in the case that the
    # majority HAVE changed, since it has to compare all globals.
    # It may also be useful to turn this off for testing worst case
    # save timing.
    attr_accessor :dont_save_default_values
    alias_method :dont_save_default_values?, :dont_save_default_values

    def to_hash
      export = {}

      self.globals.each do |key, value|
        if dont_save_default_values?
          # Don't write out values that are the same as the default global
          # values
          if default_global_variables.has_key?(key)
            if runtime_objects_equal?(default_global_variables[key], value)
              next
            end
          end
        end

        export[key] = value
      end

      return export
    end

    def runtime_objects_equal?(object_1, object_2)
      if object_1.class != object_2.class
        return false
      end

      # Perform equality on int/float manually to avoid boxing
      if object_1.is_a?(IntValue) || object_1.is_a?(FloatValue)
        return object_1.value == object_2.value
      end

      if object_1.is_a?(Value)
        return object_1.value_object.equals(object_2.value_object)
      end

      raise Error, "FastRoughDefinitelyEquals: Unsupported runtime object type: #{object_1.class}"
    end

    def get_variable_with_name(variable_name)
      return get_variable_with_name_internal(variable_name, -1)
    end

    def get_default_variable_value(variable_name)
      return self.default_global_variables[variable_name]
    end

    def global_variable_exists_with_name?(variable_name)
      globals.has_key?(variable_name) || (!default_global_variables.nil? && default_global_variables.has_key?(variable_name))
    end

    def get_variable_with_name_internal(variable_name, context_index)
      variable_value = get_raw_variable_with_name(variable_name, context_index)

      # Get value from pointer?
      if variable_value.is_a?(VariablePointerValue)
        variable_value = value_at_variable_pointer(variable_value)
      end

      return variable_value
    end

    def get_raw_variable_with_name(variable_name, context_index)
      varibale_value = nil
      if context_index == 0 || context_index == -1
        if !patch.nil? && patch.get_global(variable_name)
          return patch.get_global(variable_name)
        end

        if globals.has_key?(variable_name)
          return globals[variable_name]
        end

        # Getting variables can actually happen during global setup because
        # you can do VAR x = A_LIST_ITEM
        # so default_global_variables may be null
        # WE need to do this check though in case a new global is added, so we need to
        # revert to the default globals dictionary, since an initial value hasn't been set yet
        if !default_global_variables.nil? && default_global_variables.has_key?(variable_name)
          return default_global_variables[variable_name]
        end

        list_item_value = list_definitions_origins.find_single_item_list_with_name(variable_name)

        if list_item_value
          return list_item_value
        end
      end

      # Temporary
      return callstack.get_temporary_variable_with_name(variable_name, context_index)
    end

    def assign(variable_assignment, value)
      name = variable_assignment.variable_name
      context_index = -1

      # Are we assigning to a global variable?
      set_global = false
      if variable_assignment.new_declaration?
        set_global = variable_assignment.global?
      else
        set_global = global_variable_exists_with_name?(name)
      end

      # Constructing new variable pointer reference
      if variable_assignment.new_declaration?
        if value.is_a?(VariablePointerValue)
          fully_resolved_variable_pointer = resolve_variable_pointer!(value)
          value = fully_resolved_variable_pointer
        end
      # Assign to existing variable pointer?
      # then assign to the variable that the pointer is pointing to by name
      else
        # De-reference variable reference to point to
        existing_pointer = get_raw_variable_with_name(name, context_index)
        while existing_pointer && existing_pointer.is_a?(VariablePointerValue)
          name = existing_pointer.variable_name
          context_index = existing_pointer.context_index
          set_global = (context_index == 0)
          existing_pointer = get_raw_variable_with_name(name, context_index)
        end
      end

      if set_global
        set_global(name, value)
      else
        callstack.set_temporary_variable(name, value, variable_assignment.new_declaration?, context_index)
      end
    end

    def snapshot_default_globals
      self.default_global_variables = self.globals.dup
    end

    def set_global(variable_name, value)
      old_value = nil
      if patch.nil? || !patch.get_global(variable_name)
        old_value = globals[variable_name]
      end

      ListValue.retain_list_origins_for_assignment(old_value, value)

      if !patch.nil?
        patch.set_global(variable_name, value)
      else
        self.globals[variable_name] = value
      end

      if !variable_did_change_event.nil? && !value.equals(old_value)
        if batch_observing_variable_changes
          if !patch.nil?
            patch.add_changed_variable(variable_name)
          elsif !changed_variables_for_batch_observing.nil?
            changed_variables_for_batch_observing << variable_name
          end
        else
          variable_changed_event(variable_name, value)
        end
      end
    end

    # Given a variable pointer with just the name of the target known, resolve to a variable
    # pointer that more specifically points to the exact instance: whether it's global,
    # or the exact position of a temporary on the callstack.
    def resolve_variable_pointer!(variable_pointer)
      context_index = variable_pointer.context_index

      if context_index == -1
        context_index = get_context_index_of_variable_named(variable_pointer.variable_name)
      end

      value_of_variable_pointed_to = get_raw_variable_with_name(variable_pointer.variable_name, context_index)

      # Extra layer of indirection:
      # When accessing a pointer to a pointer (e.g. when calling nested or
      # recursive functions that take a variable references, ensure we don't create
      # a chain of indirection by just returning the final target.
      if value_of_variable_pointed_to.is_a?(VariablePointerValue)
        return value_of_variable_pointed_to
      # Make a copy of the variable pointer so we're not using the value directly
      # from the runtime. Temporary must bne local to the current scope
      else
        return VariablePointerValue.new(variable_pointer.variable_name, context_index)
      end
    end

    # 0 if named variable is global
    # =! if named variable is a temporary in a particular callstack element
    def get_context_index_of_variable_named(variable_name)
      if global_variable_exists_with_name?(variable_name)
        return 0
      end

      return callstack.current_element_index
    end
  end
end