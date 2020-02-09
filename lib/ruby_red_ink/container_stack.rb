module RubyRedInk
  class ContainerStack
    attr_accessor :container, :element_tree

    def initialize(container)
      self.container = container
      self.element_tree = {}
      build_element_tree
    end

    def elements
      container.elements_array
    end

    def build_element_tree
      elements.each_with_index do |element, index|
        element_tree[index] = element
        if element.is_a?(Container) && !element.name.nil?
          element_tree[element.name] = element
        end
      end
    end

    def path_string_for_key(key)
      if element_tree.has_key?(key)
        Path.append_path_string(container.path_string, key)
      end
    end

    def path_string_for(element)
      if element_tree.has_value?(element)
        path_string_for_key(element_tree.key(element))
      end
    end
  end
end