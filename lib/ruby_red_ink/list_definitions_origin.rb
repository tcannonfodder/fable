module RubyRedInk
  class ListDefinitionsOrigin
    attr_accessor :_lists, :all_unambiguous_list_value_cache

    def lists
      self._lists.map{|k,v| v}
    end

    def initialize(lists)
      self._lists = {}
      self.all_unambiguous_list_value_cache = {}

      lists.each do |list|
        self._lists[list.name] = list

        list.items.each do |item, int_value|
          list_value = ListValue.new(item, int_value)

          # May be ambiguous, but compiler should've caught that,
          # so we may be doing some replacement here, but that's okay
          all_unambiguous_list_value_cache[item.item_name] = list_value
          all_unambiguous_list_value_cache[item.full_name] = list_value
        end
      end
    end

    def find_single_item_list_with_name(name)
      return all_unambiguous_list_value_cache[name]
    end
  end
end