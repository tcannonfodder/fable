module RubyRedInk
  class Path
    PARENT_ID = "^".freeze

    attr_accessor :components, :relative

    def relative?
      relative == true
    end

    def head
      components.first
    end

    def tail
      if components.size >= 2
        self.class.new(components[1..])
      else
        Path.self
      end
    end

    def empty?
      length == 0
    end

    def length
      components.size
    end

    def contains_named_component?
      components.any?{|x| !x.is_index? }
    end

    def self.self
      path = self.new
      path.relative = true
      path
    end

    def initialize(components, relative= false)
      if components.is_a?(String)
        parse_components_string(components)
      else
        self.components = components
        self.relative = relative
      end
    end

    def path_by_appending_path(path_to_append)
      new_path = Path.new("")

      upward_moves = 0

      path_to_append.components.each do |component|
        if component.is_parent?
          upward_moves += 1
        else
          break
        end
      end

      components_to_add_at_this_level = (0..(components.size - upward_moves))

      components_to_add_at_this_level.each do |i|
        new_path.components << components[i]
      end

      components_to_add_after_upward_move = (upward_moves..path_to_append.components.size)

      components_to_add_after_upward_move.each do |i|
        new_path.components << path_to_append.components[i]
      end

      new_path
    end

    def path_by_appending_component(component)
      if !component.is_a?(Path::Component)
        component = Component.new(Component.component_type(component))
      end
      new_path = Path.new("")

      new_path.components += self.components

      new_path.components << component
      new_path
    end

    def components_string
      string = components.map{|x| x.to_s}.join('.')
      if relative?
        string = ".#{string}"
      end

      string
    end

    def parse_components_string(components_string)
      self.components = []
      return if components_string.strip.empty?

      # Relative path when components staet with "."
      # example: .^.^.hello.5 is equivalent to filesystem path
      # ../../hello/5

      if components_string.start_with?(".")
        @relative = true
      else
        @relative = false
      end

      components_string.split('.').each do |section|
        next if section.empty? #usually the first item in a relative path

        components << Component.new(Component.component_type(section))
      end
    end

    def ==(other_path)
      return false if other_path.nil?
      return false if other_path.components.size != components.size
      return false if other_path.relative? != relative?
      return other_path.components == components
    end

    def to_s
      components_string
    end

    class Component
      attr_accessor :index, :name

      def is_index?
        index >= 0
      end

      def is_parent?
        name == Path::PARENT_ID
      end

      def self.component_type(value)
        if value.is_a?(Numeric) || value.match?(/^\d+$/)
          return {index: Integer(value)}
        else
          return {name: value}
        end
      end

      def initialize(options)
        if options[:index]
          self.index = options[:index]
          self.name = nil
        elsif options[:name]
          self.name = options[:name]
          self.index = -1
        end
      end

      def to_s
        if is_index?
          index.to_s
        else
          name
        end
      end

      def ==(other_component)
        return false if other_component.nil?

        if self.is_index? == other_component.is_index?
          if is_index?
            return self.index == other_component.index
          else
            return self.name == other_component.name
          end
        end

        return false
      end

      def self.parent_component
        self.new(name: Path::PARENT_ID)
      end
    end
  end
end