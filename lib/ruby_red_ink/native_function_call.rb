module RubyRedInk
  class NativeFunctionCall < RuntimeObject
    extend NativeFunctionOperations

    FUNCTIONS = {
      # native functions
      ADDITION: "+",
      SUBTRACTION: "-",
      DIVIDE: "/",
      MULTIPLY: "*",
      MODULO: "%",
      NEGATE: "_",

      EQUALS: "==",
      GREATER_THAN: ">",
      LESS_THAN: "<",
      GREATER_THAN_OR_EQUAL_TO: ">=",
      LESS_THAN_OR_EQUAL_TO: "<=",
      NOT_EQUAL: "!=",
      NOT: "!",


      AND: "&&",
      OR: "||",

      MIN: "MIN",
      MAX: "MAX",

      POWER: "POW",
      FLOOR: "FLOOR",
      CEILING: "CEILING",
      INT_VALUE: "INT",
      FLOAT_VALUE: "FLOAT",

      HAS: "?",
      HAS_NOT: "!?",
      INTERSECTION: "^",

      LIST_MINIMUM: "LIST_MIN",
      LIST_MAXIMUM: "LIST_MAX",
      LIST_ALL:     "LIST_ALL",
      LIST_COUNT:   "LIST_COUNT",
      VALUE_OF_LIST: "LIST_VALUE",
      LIST_INVERT:  "LIST_INVERT",
    }.freeze

    NUMBER_OF_PARAMETERS = {
      ADDITION: 2,
      SUBTRACTION: 2,
      DIVIDE: 2,
      MULTIPLY: 2,
      MODULO: 2,
      NEGATE: 1,

      EQUALS: 2,
      GREATER_THAN: 2,
      LESS_THAN: 2,
      GREATER_THAN_OR_EQUAL_TO: 2,
      LESS_THAN_OR_EQUAL_TO: 2,
      NOT_EQUAL: 2,
      NOT: 1,


      AND: 2,
      OR: 2,

      MIN: 2,
      MAX: 2,

      POWER: 2,
      FLOOR: 1,
      CEILING: 1,
      INT_VALUE: 1,
      FLOAT_VALUE: 1,

      HAS: 2,
      HAS_NOT: 2,
      INTERSECTION: 2,

      LIST_MINIMUM: 1,
      LIST_MAXIMUM: 1,
      LIST_ALL:     1,
      LIST_COUNT:   1,
      VALUE_OF_LIST: 1,
      LIST_INVERT:  1,
    }.freeze

    LOOKUP = FUNCTIONS.invert.freeze

    attr_accessor :name, :number_of_parameters

    def initialize(function_symbol)
      self.name = LOOKUP[function_symbol]
      self.number_of_parameters = NUMBER_OF_PARAMETERS[self.name]
    end

    def call!(parameters)
      if parameters.size != self.number_of_parameters
        raise StoryException, "Unexpected number of parameters"
      end

      has_list = false

      parameters.each do |parameter|
        case parameter
        when Void
          raise StoryException, "Attempting to perform operation on a void value. Did you forget to 'return' a value from a function you called here?"
        when ListValue
          has_list = true
        end
      end

      # Binary operations on lists are treated outside of the standard coercion rules
      if parameters.size == 2 && has_list
        return call_binary_list_operation(parameters)
      end

      coerced_parameters = coerce_values_to_single_type(parameters)

      return underlying_function_call(coerced_parameters)
    end

    def underlying_function_call(parameters)
      parameter_1 = parameters.first
      value_type = parameter_1.class

      if parameters.size > 2
        raise Error, "Unexpected number of parameters to NativeFunctionCall: #{parameters.size}"
      end

      if !can_perform_function_on?(value_type)
        raise Error, "Cannot perform operation '#{self.name}' on #{value_type}"
      end

      # Binary function
      if parameters.size == 2
        parameter_2 = parameters.last
        result = run_operation(parameter_1.value, parameter_2.value)

        return Value.create(result)
      # Unary Function
      else
        result = run_operation(parameter_1.value)
        return Value.create(result)
      end

      def call_binary_list_operation(parameters)
        value_1 = parameters[0]
        value_2 = parameters[1]

        # List-Int addition/subtraction returns a List (eg: "alpha" + 1 = "beta")
        if (name == FUNCTIONS[:ADDITION] || name == FUNCTIONS[:SUBTRACTION]) && value_1.is_a?(ListValue) && value_2.is_a?(IntValue)
          return call_list_increment_operation(parameters)
        end

        # And/or with any other types required coercion to bool (int)
        if (name == FUNCTIONS[:AND] || FUNCTIONS[:OR]) && (!value_1.is_a?(ListValue) || !value_2.is_a?(ListValue))
          value_1_as_boolean = value_1.is_truthy? ? 1 : 0
          value_2_as_boolean = value_2.is_truthy? ? 1 : 0

          result = run_operation(value_1_as_boolean, value_2_as_boolean)
          return IntValue.new(result)
        end

        # Normal (list X list) operation
        if value_1.is_a?(ListValue) && value_2.is_a?(ListValue)
          return run_operation([value_1, value_2])
        end

        raise Error, "Can not call '#{name}' operation on '#{value_1.class}' and '#{value_2.class}'"
      end

      def call_list_increment_operation(parameters)
        list_value = parameters[0]
        int_value = parameters[1]

        result_list = InkList.new

        list_value.value.items.each do |list_item, list_item_value|
          target_integer = run_operation(list_item_value, int_value.value)

          # Find this item's origin
          item_origin = list_value.value.origins.find{|origin| origin.name == list_item.origin_name }

          if !item_origin.nil?
            incremented_item = item_origin.item_for_value(target_integer)
            if !incremented_item.nil?
              result_list.add(incremented_item, target_integer)
            end
          end
        end

        return ListValue.new(result_list)
      end

      def coerce_values_to_single_type(parameters)
        given_types = parameters.map(&:class)
        special_case_list = parameters.find{|x| x.is_a?(ListValue) }

        # Find out what the output type is; "higher-level" types infect both
        # so that binary operations use the same type on both sides
        # (eg: binary operation of int & float causes the int to be casted as a float)
        value_type = ([IntValue] + given_types).max{|a,b| OrderedValueTypes[a] <=> OrderedValueTypes[b] }

        # Coerce to this chosen type
        parameters_out = []

        # Special case: Coercing Ints to Lists
        # We have to do it early when we have both parameters
        # to hand, so that we can make use of the list's origin
        if value_type == ListValue
          parameters.each do |parameter|
            if parameter.is_a?(ListValue)
              parameters_out << parameter
            elsif parameter.is_a?(IntValue)
              int_value = parameter.value
              list = special_case_list.value.origin_of_max_item

              item = list.item_for_value(int_value)

              if !item.nil?
                parameters_out << ListValue.new(item, int_value)
              else
                raise Error, "Could not find List item with the value '#{int_value}' in #{list.name}"
              end
            else
              raise Error, "Cannot mix Lists and #{parameter.class} values in this operation"
            end
          end
        # Normal coercing, with standard casting
        else
          parameters.each do |parameter|
            parameters_out << parameter.cast(value_type)
          end
        end

        return parameters_out
      end

      def as_string
        "Native '#{name}'"
      end

      protected

      def run_operation(*parameters)
        case name
        when :ADDITION
          return self.class.addition(parameters[0], parameters[1])
        when :SUBTRACTION
          return self.class.subtraction(parameters[0], parameters[1])
        when :DIVIDE
          return self.class.divide(parameters[0], parameters[1])
        when :MULTIPLY
          return self.class.divide(parameters[0], parameters[1])
        when :MODULO
          return self.class.modulo(parameters[0], parameters[1])
        when :NEGATE
          return self.class.negate(parameter[0])
        when :EQUALS
          return self.class.equal(parameters[0], parameters[1])
        when :GREATER_THAN
          return self.class.greater(parameters[0], parameters[1])
        when :LESS_THAN
          return self.class.less(parameters[0], parameters[1])
        when :GREATER_THAN_OR_EQUAL_TO
          return self.class.greater_than_or_equal(parameters[0], parameters[1])
        when :LESS_THAN_OR_EQUAL_TO
          return self.class.less_than_or_equal(parameters[0], parameters[1])
        when :NOT_EQUAL
          return self.class.not_equal(parameters[0], parameters[1])
        when :NOT
          return self.class.not(parameters[0])
        when :AND
          return self.class.and(parameters[0], parameters[1])
        when :OR
          return self.class.or(parameters[0], parameters[1])
        when :MIN
          return self.class.min(parameters[0], parameters[1])
        when :MAX
          return self.class.max(parameters[0], parameters[1])
        when :POWER
          return self.class.pow(parameters[0], parameters[1])
        when :FLOOR
          return self.class.floor(parameters[0])
        when :CEILING
          return self.class.ceil(parameters[0])
        when :INT_VALUE
          return self.class.int_value(parameters[0])
        when :FLOAT_VALUE
          return self.class.float_value(parameters[0])
        when :HAS
          return self.class.has(parameters[0], parameters[1])
        when :HAS_NOT
          return self.class.has_not(parameters[0], parameters[1])
        when :INTERSECTION
          return self.class.intersection(parameters[0], parameters[1])
        when :LIST_MINIMUM
          return self.class.list_min(parameters[0])
        when :LIST_MAXIMUM
          return self.class.list_max(parameters[0])
        when :LIST_ALL
          return self.class.all(parameters[0])
        when :LIST_COUNT
          return self.class.count(parameters[0])
        when :VALUE_OF_LIST
          return self.class.value_of_list(parameters[0])
        when :LIST_INVERT
          return self.class.invert(parameters[0])
        end
      end
    end

    module NativeFunctionOperations
      def addition(x, y)
        return x + y
      end

      def subtraction(x,y)
        return x - y
      end

      def multiply(x,y)
        return x * y
      end

      def divide(x,y)
        x / y
      end

      def modulo(x,y)
        return x % y
      end

      def negate(x)
        return -x
      end

      def equal(x,y)
        return (x == y) ? 1 : 0
      end

      def greater(x,y)
        return (x > y) ? 1 : 0
      end

      def less(x,y)
        return (x < y) ? 1 : 0
      end

      def greater_than_or_equal(x,y)
        return (x >= y) ? 1 : 0
      end

      def less_than_or_equal(x,y)
        return (x <= y) ? 1 : 0
      end

      def not_equal(x,y)
        return (x != y) ? 1 : 0
      end

      def not(x)
        if x.is_a?(InkList)
          return (x.size == 0) ? 1 : 0
        else
          return (x == 0) ? 1 : 0
        end
      end

      def and(x,y)
        if x.is_a?(InkList)
          return (x.size > 0 && y.size > 0) ? 1 : 0
        else
          return (x != 0 && y != 0) ? 1 : 0
        end
      end

      def or(x,y)
        if x.is_a?(InkList)
          return (x.size > 0 || y.size > 0) ? 1 : 0
        else
          return (x != 0 || y != 0) ? 1 : 0
        end
      end

      def max(x,y)
        return [x,y].max
      end

      def min(x,y)
        return [x,y].min
      end

      def pow(x,y)
        return x ** y
      end

      def floor(x)
        x.floor
      end

      def ceiling(x)
        x.ceil
      end

      def int_value(x)
        x.to_i
      end

      def float_value(x)
        x.to_f
      end

      def has(x,y)
        if x.is_a?(InkList)
          return x.contains?(y) ? 1 : 0
        else
          return x.include?(y) ? 1 : 0
        end
      end

      def has_not(x,y)
        !has(x,y) ? 1 : 0
      end

      def intersection(x,y)
        return x & y
      end

      def invert(x)
        x.inverse
      end

      def all(x)
        x.all
      end

      def list_min(x)
        x.min_as_list
      end

      def list_max(x)
        x.max_as_list
      end

      def count(x)
        x.count
      end

      def value_of_list(x)
        x.max_item[1]
      end
    end
  end
end