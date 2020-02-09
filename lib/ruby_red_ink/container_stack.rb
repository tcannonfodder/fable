module RubyRedInk
  class ContainerStack
    attr_accessor :container, :elements

    def initialize(container)
      self.container = container
      self.elements = {}
      process_elements
    end

    def process_elements
      container.elements_array.each_with_index do |element, index|
        elements[index] = element
        if element.is_a?(Container) && !element.name.nil?
          elements[element.name] = element
        end
      end
    end

    def path_string_for_key(key)
      if elements.has_key?(key)
        Path.append_path_string(container.path_string, key)
      end
    end

    def path_string_for(element)
      if elements.has_value?(element)
        path_string_for_key(elements.key(element))
      end
    end
  end
end