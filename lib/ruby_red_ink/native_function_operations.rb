module RubyRedInk
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