module RubyRedInk
  class ContainerStack
    attr_accessor :elements, :elements_hash

    def initialize(elements)
      self.elements = elements
      self.elements_hash = {}
      process_elements
    end

    def process_elements
      elements.each_with_index do |element, index|
        elements_hash[index] = element
        if element.is_a?(Container) && !element.name.nil?
          elements_hash[element.name] = element
        end
      end
    end
  end
end