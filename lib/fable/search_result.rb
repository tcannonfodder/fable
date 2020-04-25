module Fable
  class SearchResult
    attr_accessor :object, :approximate

    alias_method :approximate?, :approximate

    def correct_object
      if approximate?
        return nil
      else
        return object
      end
    end

    def container
      return nil if !object.is_a?(Container)
      return object
    end
  end
end