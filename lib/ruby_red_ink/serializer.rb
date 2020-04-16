module RubyRedInk
  class Serializer
    def self.convert_to_runtime_objects(objects, skip_last = false)
      last_item = objects.last
      runtime_objects = []

      objects.each do |object|
        next if object == last_item && skip_last
        runtime_objects << convert_to_runtime_object(object)
      end

      runtime_objects
    end

    def self.convert_to_runtime_objects_hash(hash)
      runtime_hash = {}

      hash.each do |key, value|
        runtime_hash[key] = convert_to_runtime_object(value)
      end

      return runtime_hash
    end

    def self.array_to_container(array)
      contents = convert_to_runtime_objects(array, true)
      # Final object in the array is always a combination of
      # - named content
      # - an #f key with the count flags
      final_object = array.last
      bit_flags = 0
      container_name = nil
      named_only_content = {}

      if !final_object.nil?
        final_object.each do |key, value|
          if key == "#f"
            bit_flags = value.to_i
          elsif key == "#n"
            container_name = value
          else
            named_content_item = convert_to_runtime_object(value)
            if named_content_item.is_a?(Container)
              named_content_item.name = key
            end

            named_only_content[key] = named_content_item
          end
        end
      end

      container = Container.new(bit_flags)
      container.add_content(contents)
      if !container_name.nil?
        container.name = container_name
      end

      container.named_content = named_only_content

      return container
    end

    # ----------------------
    # JSON ENCODING SCHEME
    # ----------------------
    #
    # Glue:           "<>", "G<", "G>"
    #
    # ControlCommand: "ev", "out", "/ev", "du" "pop", "->->", "~ret", "str", "/str", "nop",
    #                 "choiceCnt", "turns", "visit", "seq", "thread", "done", "end"
    #
    # NativeFunction: "+", "-", "/", "*", "%" "~", "==", ">", "<", ">=", "<=", "!=", "!"... etc
    #
    # Void:           "void"
    #
    # Value:          "^string value", "^^string value beginning with ^"
    #                 5, 5.2
    #                 {"^->": "path.target"}
    #                 {"^var": "varname", "ci": 0}
    #
    # Container:      [...]
    #                 [...,
    #                     {
    #                         "subContainerName": ...,
    #                         "#f": 5,                    # flags
    #                         "#n": "containerOwnName"    # only if not redundant
    #                     }
    #                 ]
    #
    # Divert:         {"->": "path.target", "c": true }
    #                 {"->": "path.target", "var": true}
    #                 {"f()": "path.func"}
    #                 {"->t->": "path.tunnel"}
    #                 {"x()": "externalFuncName", "exArgs": 5}
    #
    # Var Assign:     {"VAR=": "varName", "re": true}   # reassignment
    #                 {"temp=": "varName"}
    #
    # Var ref:        {"VAR?": "varName"}
    #                 {"CNT?": "stitch name"}
    #
    # ChoicePoint:    {"*": pathString,
    #                  "flg": 18 }
    #
    # Choice:         Nothing too clever, it's only used in the save state,
    #                 there's not likely to be many of them.
    #
    # Tag:            {"#": "the tag text"}

    def self.convert_to_runtime_object(object)
      case object
      when Numeric
        return Value.create(object)
      when String
        string = object

        # StringValue
        if string.start_with?("^")
          return StringValue.new(string[1..-1])
        elsif string.start_with?("\n") && string.length == 1
          return StringValue.new("\n")
        end

        # Glue
        if string == "<>"
          return Glue.new
        end

        # Control Commands
        if ControlCommand.is_control_command?(string)
          return ControlCommand.get_control_command(string)
        end

        # Native functions
        # "^" conflicts with the way we identify strings, so now
        # we know it's not a string, we can convert back to the proper symbol
        # for this operator
        if string == "L"
          string = "^"
        end

        if NativeFunctionCall.is_native_function?(string)
          return NativeFunctionCall.new(string)
        end

        # Pop
        if string == ControlCommand::COMMANDS[:POP_TUNNEL]
          return ControlCommand.get_control_command(string)
        elsif string == ControlCommand::COMMANDS[:POP_FUNCTION]
          return ControlCommand.get_control_command(string)
        end

        if string == "void"
          return Void.new
        end
      when Hash
        given_hash = object

        # Divert target value to path
        if given_hash["^->"]
          return DivertTargetValue.new(Path.new(given_hash["^->"]))
        end

        # VariablePointerType
        if given_hash["^var"]
          variable_pointer = VariablePointerValue.new(given_hash["^var"])
          if given_hash["ci"]
            variable_pointer.context_index = given_hash["ci"]
          end

          return variable_pointer
        end

        # Divert
        is_divert = false
        pushes_to_stack = false
        divert_push_pop_type = PushPopType::TYPES[:function]
        external = false
        value = nil

        if given_hash["->"]
          is_divert = true
          value = given_hash["->"]
        elsif given_hash["f()"]
          is_divert = true
          pushes_to_stack = true
          divert_push_pop_type = PushPopType::TYPES[:function]
          value = given_hash["f()"]
        elsif given_hash["->t->"]
          is_divert = true
          pushes_to_stack = true
          divert_push_pop_type = PushPopType::TYPES[:tunnel]
          value = given_hash["->t->"]
        elsif given_hash["x()"]
          is_divert = false
          external = true
          pushes_to_stack = false
          divert_push_pop_type = PushPopType::TYPES[:function]
          value = given_hash["x()"]
        end

        if is_divert
          divert = Divert.new
          divert.pushes_to_stack = pushes_to_stack
          divert.stack_push_type = divert_push_pop_type
          divert.is_external = external
          target = value.to_s

          if given_hash["var"]
            divert.variable_divert_name = target
          else
            divert.target_path_string = target
          end

          divert.is_conditional = given_hash.has_key?("c")

          if external
            if given_hash["exArgs"]
              divert.external_arguments = given_hash["exArgs"]
            end
          end

          return divert
        end

        # Choice
        if given_hash["*"]
          choice = ChoicePoint.new
          choice.path_string_on_choice = given_hash["*"]

          if given_hash["flg"]
            choice.flags = given_hash["flg"]
          end

          return choice
        end

        # Variable Reference
        if given_hash["VAR?"]
          return VariableReference.new(given_hash["VAR?"])
        elsif given_hash["CNT?"]
          read_count_variable_reference = VariableReference.new
          read_count_variable_reference.path_string_for_count = given_hash["CNT?"]
          return read_count_variable_reference
        end

        # Variable Assignment
        is_variable_assignment = false
        is_global_variable = false

        if given_hash["VAR="]
          variable_name = given_hash["VAR="]
          is_variable_assignment = true
          is_global_variable = true
        elsif given_hash["temp="]
          variable_name = given_hash["temp="]
          is_variable_assignment = true
          is_global_variable = false
        end

        if is_variable_assignment
          is_new_declaration = !given_hash.has_key?("re")
          variable_assignment = VariableAssignment.new(variable_name, is_new_declaration)
          variable_assignment.global = is_global_variable
          return variable_assignment
        end

        # Tag
        if given_hash["#"]
          return Tag.new(given_hash["#"])
        end

        # List
        if given_hash["list"]
          list_content = given_hash["list"]
          raw_list = InkList.new
          if given_hash["origins"]
            raw_list.set_initial_origin_names(given_hash["origins"])
          end

          list_content.each do |key, value|
            item = InkList::InkListItem.new(key)
            raw_list.add(item, value.to_i)
          end

          return ListValue.new(raw_list)
        end

        # Used when serializing save state only
        if given_hash["originalChoicePath"]
          return object_to_choice(object)
        end
      when Array
        return array_to_container(object)
      when NilClass
        return nil
      else
        raise Error, "Failed to convert to runtime object: #{object}"
      end
    end

    def self.object_to_choice(object)
      choice = Choice.new
      choice.text = object["text"]
      choice.index = object["index"].to_i
      choice.source_path = object["originalChoicePath"]
      choice.original_thread_index = object["originalThreadIndex"].to_i
      choice.path_string_on_choice = object["targetPath"]
      return choice
    end

    def self.convert_to_list_definitions(object)
      all_definitions = []

      object.each do |name, list_definition_hash|
        items = {}
        list_definition_hash.each do |key, value|
          items[key] = value.to_i
        end

        all_definitions << ListDefinition.new(name, items)
      end

      return ListDefinitionsOrigin.new(all_definitions)
    end
  end
end