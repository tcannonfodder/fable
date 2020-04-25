module Fable
  class ListDefinition
    attr_accessor :name, :items

    # The main representation should be simple item names, rather than a
    # RawListItem, since we mainly want to access items based on their
    # simple name, since that's how they'll be most commonly requested
    # from ink
    attr_accessor :item_name_to_values

    def items
      if @items.nil?
        @items = {}
        @item_name_to_values.each do |key, value|
          item = InkList::InkListItem.new(origin_name: name, item_name: key)
          @items[item] = value
        end
      end
      @items
    end

    def value_for_item(item)
      return item_name_to_values[item.item_name] || 0
    end

    def contains?(item)
      return false if item.origin_name != self.name
      return contains_item_with_name?(item.item_name)
    end

    def contains_item_with_name?(item_name)
      return item_name_to_values.has_key?(item_name)
    end

    def item_for_value(int_value)
      return item_name_to_values.key(int_value)
    end

    def initialize(name, items)
      self.name = name
      self.item_name_to_values = items
    end
  end
end