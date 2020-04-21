module RubyRedInk
  # The InkList is the underlying type that's used to store an instance of a
  # list in ink. It's not used for the *definition* of the list, but for a list
  # value that's stored in a variable.
  class InkList
    # The underlying type for a list item in ink. It stores the original list definition
    # name as well as the item name, but without the value of the item. When the value is
    # stored, it's stored in a Dictionary of InkListItem and an integer.
    class InkListItem
      #The name of the list where the item was originally defined.
      attr_accessor :origin_name

      # The main name of the item as defined in ink
      attr_accessor :item_name

      def initialize(options)
        # Create an item from a dot-separated string of the form
        # `list_definition_name.list_item_name`
        if options.has_key?(:full_name)
          name_parts = options[:full_name].split(".")
          self.origin_name = name_parts[0]
          self.item_name = name_parts[1]
        else
          self.origin_name = options[:origin_name]
          self.item_name = options[:item_name]
        end
      end

      def self.Null
        return self.new(nil, nil)
      end

      def null_item?
        origin_name.nil? && item_name.null?
      end

      # Get the full dot-separated name of the item, in the form of
      # `list_definition_name.list_item_name`
      def full_name
        return "#{origin_name.nil? ? "?" : origin_name}.#{item_name}"
      end

      alias_method :to_s, :full_name

      def equal?(other_object)
        return false if !other_object.is_a?(InkListItem)

        return (
          other_object.item_name == self.item_name &&
          other_object.origin_name == self.origin_name
        )
      end
    end


    attr_accessor :list, :origins

    # Create a new empty ink list
    def initialize
      self.list = {}
      self.origins = []
    end

    # Create a new ink list that contains the same contents as another list
    def self.new_from_list_contents(other_list_or_single_item)
      ink_list = self.new

      if other_list_or_single_item.is_a?(Array)
        ink_list.list = Hash[[other_list_or_single_item]]
      else
        ink_list.list = Hash[other_list_or_single_item.list]
        ink_list.origin_names = other_list_or_single_item.origin_names
      end

      return ink_list
    end

    # Create a new empty ink list that's intended to hold items from a
    # particular origin list definition. The origin story is needed in order
    # to be able to look up that definition
    def self.new_for_origin_definition_and_story(single_origin_list_name, origin_story)
      ink_list = self.new
      ink_list.set_initial_origin_name(single_origin_list_name)

      list_definition = origin_story.list_definitions[single_origin_list_name]
      if list_definition.nil?
        raise Error("InkList origin could not be found in story when constructing new list: #{single_origin_list_name}")
      else
        ink_list.origins = [list_definition]
      end
    end

    # Converts a string to an ink list, and returns for use in the Story
    def self.from_string(my_list_item, origin_story)
      list_value = origin_story.list_definitions[my_list_item]
      if list_value.nil?
        raise Error("Could not find the InkListItem from the string '#{my_list_item}' to create an InkList because it doesn't exist in the original list definition in ink.")
      else
        return self.new(list_value)
      end
    end

    def add_item(item_or_item_name)
      if item_or_item_name.is_a?(InkListItem)
        add_ink_list_item(item_or_item_name)
      else
        add_item_from_string(item_or_item_name)
      end
    end

    # Adds the given item to the ink list. Note that the item must come from a list
    # definition that is already "known" to this list, so that teh item's value can be
    # looked up. By "known", we mean that it alreadyu has items in it from that source,
    # or did at one point. It can't be a completely fresh empty list, or a list that only
    # contains items from a different list definition
    def add_ink_list_item(item)
      if item.origin_name.nil?
        return add_item_from_string(item.item_name)
      end

      origins.each do |origin|
        if origin.name == item.origin_name
          integer_value = origin.items[item]

          if integer_value.nil?
            raise Error("Could not add the item '#{item.item_name}' to this list because it doesn't exist in the original list definition in ink.")
          else
            self.list[item] = integer_value
          end
        end
      end

      raise Error("Failed to add item to list because the item was from a new list definition that wasn't previously known to this list. Only items from previously known lists can be used, so that the int value can be found.")
    end

    # Adds the given item to the ink list, attempting to find the origin list definition
    # that it belongs to. The item must therefore come from a list definition that is already
    # "known" to this list, so that the item's value can be looked up. By "known", we mean that it
    # already has items in it from that source, or it did at one point. It can't be a completely
    # fresh empty list, or a list that only contains items from a different list definition
    def add_item_from_string(item_name)
      found_list_definition = nil
      origins.each do |origin|
        if origin.items.any?{|item, int_value| item.name == item_name }
          if found_list_definition.nil?
            found_list_definition = origin
          else
            raise Error("Could not add the item '#{item_name}' to this list because it could come from either '#{origin.name}' or '#{found_list_definition.name}'")
          end
        end
      end

      if found_list_definition.nil?
        raise Error("Could not add the item '#{item_name}' to this list because it isn't known to any list definitions previously associated with this list.")
      end

      item = InkListItem.new(origin_name: found_list_definition.name, item_name: item_name)
      item_value = found_list_definition.value_for_item(item)
      self.items[item] = item_value
    end

    def include_item_named?(item_name)
      list.any?{|item, int_value|  item.name == item_name}
    end

    # Story has to set this so that the value knows its origin, necessary for
    # certain operations (eg: iteracting with ints). Only the story has access
    # to the full set of lists, so that the origin can be resolved from the
    # origin_list_name
    def origin_of_max_item
      return nil if origins.nil?
      max_origin_name = max_item.origin_name
      origins.find{|origin| origin.name == max_origin_name }
    end

    # Origin name needs to be serialized when content is empty, assuming
    # a name is available, for list definitions with variable that is currently
    # empty
    def origin_names
      if self.list.any?
        @origin_names = self.list.map{|item, int_value| item.origin_name }.compact.uniq
      end

      return @origin_names
    end

    def set_initial_origin_name(initial_origin_name)
      @origin_names = [initial_origin_name]
    end

    def set_initial_origin_names(initial_origin_names)
      @origin_names = initial_origin_name
    end

    def count
      items.size
    end

    # Get the maximum item in the list, equivalent to calling LIST_MAX(list) in ink.
    def max_item
      items.max do |a, b|
        return -1 if a[0].null_item?
        return 1 if b[0].null_item?
        a[1] <=> b[1]
      end
    end

    # Get the minimum item in the list, equivalent to calling LIST_MIN(list) in ink.
    def min_item
      items.min do |a, b|
        return -1 if a[0].null_item?
        return 1 if b[0].null_item?
        a[1] <=> b[1]
      end
    end

    # The inverse of the list, equivalent to colling LIST_INVERSE(list) in ink.
    def inverse
      new_list = self.class.new
      origins.each do |origin|
        origin.items.each do |item, int_value|
          if !self.list.include?(item)
            new_list.list[item, int_value]
          end
        end
      end

      new_list
    end

    # The list of all items from the original list definition, equivalent to
    # calling LIST_ALL(list) in ink.
    def all
      new_list = self.class.new
      origins.each do |origin|
        origin.items.each do |item, int_value|
          new_list.list[item, int_value]
        end
      end

      new_list
    end

    # Return a new list that is a combination of the current list and
    # one that's passed in. The equivalent of calling (list1 + list2) in ink.
    def +(other_list)
      union_list = self.class.new(self)
      other_list.list.each do |item, int_value|
        union_list[item] = int_value
      end

      return union_list
    end

    # Return a new list that is the intersection of the current list and
    # one that's passed in. The equivalent of calling (list1 ^ list2) in ink.
    def &(other_list)
      intersection_list = self.class.new
      self.list.items do |item, int_value|
        if other_list.list.has_key?(item)
          intersection_list[item] = int_value
        end
      end

      return intersection_list
    end

    # Returns a new list that's the same as the current one, except with the
    # given items removed that are in the passed-in list. Equivalent to calling
    # (list1 - list2) in ink.
    def -(other_list)
      without_list = self.class.new(self)
      other_list.list.each do |item, int_value|
        without_list.delete(item)
      end

      return without_list
    end

    # Returns true if the current list contains all the items that are in the
    # list that is passed in. Equivalent to calling (list1 ? list2) in ink.
    def contains?(other_list)
      other_list.list.all?{|item, int_value| self.list.has_key?(item) }
    end

    # Returns true if all the item values in the current list are greater than
    # all the item values in the passed-in list. Equivalent to calling
    # (list1 > list2) in ink.
    def >(other_list)
      return false if self.list.empty?
      return true if other_list.list.empty?

      return self.min_item[1] > other_list.max_item[1]
    end

    # Returns true if the item values in the current list overlap, or are all
    # greater than the item values in the passed-in list. None of the item values
    # in the current list must fall below the item values in the passed-in list
    # Equivalent to (list1 >= list2) in ink, or LIST_MIN(list1) >= LIST_MIN(list2) &&
    # LIST_MAX(list1) >= LIST_MAX(list2)
    def >=(other_list)
      return false if self.list.empty?
      return true if other_list.list.empty?

      return (
        self.min_item[1] >= other_list.min_item[1] &&
        self.max_item[1] >= other_list.max_item[1]
      )
    end

    # Returns true if all the item values in the current list are less than all the
    # item values in the passed-in list. Equivalent to calling (list1 < list2 in ink)
    def <(other_list)
      return false if other_list.list.empty?
      return true if self.list.empty?

      return self.max_item[1] < other_list.min_item[1]
    end

    # Returns true if the item values in the current list overlap, or are all less than
    # the item values in the passed in list. None of the item values in the current list
    # must go above the item values in the passed in list. Equivalent to (list1 <= list2)
    # in ink, or LIST_MAX(list1) <= LIST_MAX(list2) && LIST_MIN(list1) <= LIST_MIN(list2)
    def <=(other_list)
      return false if other_list.list.empty?
      return true if self.list.empty?

      return (
        self.max_item[1] <= other_list.max_item[1] &&
        self.min_item[1] <= other_list.min_item[1]
      )
    end

    def max_as_list
      if self.list.empty?
        return self.class.new
      else
        return self.class.new(max_item)
      end
    end

    def min_as_list
      if self.list.empty?
        return self.class.new
      else
        return self.class.new(min_item)
      end
    end

    # Returns a sublist with the elements given in the minimum & maximum
    # bounds. The bounds can either be ints, which are indicies into the entire (sorted)
    # list, or they can be InkLists themsevles. These are intended to be single-item lists,
    # so you can specify the upper & lower bounds. If you pass in multi-item lists, it'll use
    # the minimum and maximum items in those lists, respectively.
    def list_with_subrange(min_bound, max_bound)
      return self.class.new if self.list.empty?

      ordered = self.ordered_items

      min_value = 0
      max_value = Float::INFINITY

      if min_bound.is_a?(Numeric)
        min_value = min_bound
      elsif min_bound.is_a?(InkList) && !min_bound.list.empty?
        min_value = min_bound.min_item[1]
      end

      if max_bound.is_a?(Numeric)
        max_value = max_value
      elsif max_bound.is_a?(InkList) && !max_bound.list.empty?
        max_value = max_bound.max_bound[1]
      end

      sublist = self.class.new
      sublist.set_initial_origin_names(origin_names)
      ordered.each do |item, int_value|
        if int_value >= min_value && int_value <= max_value
          sublist.list[item] = int_value
        end
      end

      sublist
    end

    # Returns true if the passed object is also an ink list that contains the
    # same items as the current list, false otherwise.
    def ==(other_list)
      return false if !other_list.is_a?(InkList)
      return false if other_list.list.size != self.list.size

      return self.list.all?{|item, int_value| other_list.list.has_key?(item) }
    end

    def ordered_items
      self.list.sort do |a, b|
        # ensure consistent ordering of mixed lists
        if(a[1] == b[1])
          a[0].origin_name <=> b[0].origin_name
        else
          a[1] <=> b[1]
        end
      end
    end

    # Returns a string in the form "a, b, c" with the names of the items in the
    # list, without the origin list definition names. Equivalent to writing
    # {list} in ink
    def to_s
      ordered_items.map{|item, int_value| item.item_name }.join(", ")
    end
  end
end