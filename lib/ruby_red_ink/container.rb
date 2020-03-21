module RubyRedInk
  class Container < RuntimeObject
    attr_accessor :bit_flags, :name, :content, :named_content,
    :visits_should_be_counted, :turn_index_should_be_counted,
    :counting_at_start_only, :path_to_first_leaf_content

    def initialize(flags)
      self.bit_flags = flags
      self.content = []
      self.named_content = {}
    end

    def add_content(content_to_add)
      if content_to_add.is_a?(Enumerable)
        content_to_add.each{|individual_items| add_content(content_to_add) }
      end

      if content_to_add.parent.present?
        raise Error, "content is already in #{content_to_add.parent}"
      end

      content_to_add.parent = self
      content << content_to_add

      try_adding_to_named_content(content_to_add)
    end

    def insert_content_at(content_to_add, index)
      if content_to_add.parent.present?
        raise Error, "content is already in #{content_to_add.parent}"
      end

      content_to_add.parent = self
      content.insert(index, content_to_add)
      try_adding_to_named_content(content_to_add)
    end

    def try_adding_to_named_content(content_to_add)
      if content_to_add.respond_to?(:valid_name?) && content_to_add.valid_name?
        add_to_named_content(content_to_add)
      end
    end

    def add_to_named_content(content_to_add)
      content_to_add.parent = self
      named_content[content_to_add.name] = content_to_add
    end

    def add_contents_of_container(other_container)
      content += other_container.content
      other_container.content.each do |content_to_add|
        content_to_add.parent = self
        try_adding_to_named_content(content_to_add)
      end
    end

    def content_with_path_component(component)
      if component.is_index?
        return content[component.index]
      elsif component.is_parent?
        return self.parent
      else
        return named_content[component.name]
      end
    end

    def content_at_path(path, options= { partial_path_start: 0, partial_path_length: -1 })
      partial_path_length = options[:partial_path_length]
      partial_path_start = options[:partial_path_start]

      if partial_path_length == -1
        partial_path_length = path.length
      end

      result = SearchResult.new
      result.approximate = false

      current_container = self
      current_object = self

      (partial_path_start..partial_path_length).each do |i|
        component = path.get_component(i)

        # Path component was wrong type
        if current_container.nil?
          result.approximate = true
          break
        end

        found_object = current_container.content_with_path_component(component)

        # Couldn't resolve entire path?
        if found_object.nil?
          result.approximate = true
          break
        end

        current_object = found_object
        if found_object.is_a?(Container)
          current_container = found_object
        else
          current_container = nil
        end
      end

      result.object = current_object
      return result
    end

    def build_string_of_hierarchy(io, indentation, pointed_object)
      io << indentation_string(indentation)
      io << "["

      if self.valid_name?
        io << " (#{self.name})"
      end

      if self == pointed_object
        io << " <---"
      end

      io << "\n"

      indentation += 1


      content.each_with_index do |object, index|
        if object.is_a?(Container)
          object.build_string_of_hierarchy(io, indentation, pointed_object)
        else
          io << indentation_string(indentation)
          if object.is_a?(StringValue)
            io << "\"#{object.as_string.gsub("\n", "\\n")}\""
          else
            io << object.as_string
          end
        end

        if index != (content.size - 1)
          io << ","
        end

        if !object.is_a?(Container) && object == pointed_object
          io << " <---"
        end

        io << "\n"
      end

      only_named_content = named_content.reject{|name, item| content.include?(item) }

      if only_named_content.any?
        io << indentation_string(indentation)
        io << "-- named: --\n"

        only_named_content.each do |key, container|
          container.build_string_of_hierarchy(io, indentation, pointed_object)
          io << "\n"
        end
      end

      indentation -= 1

      io << indentation_string(indentation)
      io << "]"
    end

    def build_string_of_hierarchy
      io = StringIO.new
      build_string_of_hierarchy(io, 0, nil)

      io.rewind
      return io.read
    end

    def path_to_first_leaf_content
      @path_to_first_leaf_content || = path.path_by_appending_path(internal_path_to_first_lead_content)
    end

    def valid_name?
      !name.to_s.empty?
    end

    alias_method :visits_should_be_counted, :visits_should_be_counted?
    alias_method :turn_index_should_be_counted, :turn_index_should_be_counted?
    alias_method :counting_at_start_only, :counting_at_start_only?

    def process_bit_flags
      if has_bit_flags?
        self.visits_should_be_counted = (bit_flag & 0x1) > 0
        self.turn_index_should_be_counted = (bit_flag & 0x2) > 0
        self.counting_at_start_only = (bit_flag & 0x4) > 0
      else
        self.visits_should_be_counted = false
        self.turn_index_should_be_counted = false
        self.counting_at_start_only = false
      end
    end

    def has_bit_flags?
      self.bit_flags.present?
    end

    protected

    def internal_path_to_first_lead_content
      components = []
      container = self
      while !container.nil?
        if container.content.size > 0
          components << Path::Component.new(0)
          container = container.content.first
        end
      end

      return Path.new(components)
    end
  end
end