module RubyRedInk
  class ChoicePoint < RuntimeObject
    attr_accessor :has_condition,
      :has_start_content, :has_choice_only_content,
      :invisible_default,
      :once_only, :path_on_choice

      alias_method :invisible_default?, :invisible_default
      alias_method :has_start_content?, :has_start_content
      alias_method :has_condition?, :has_condition
      alias_method :has_choice_only_content?, :has_choice_only_content
      alias_method :once_only?, :once_only

    # The ChoicePoint represents the point within the Story
    # where a Choice instance gets generated. The distinction
    # is made because the text of the choice can be dynamically
    # generated
    def path_on_choice
      # Resolve any relative pahts to global ones as we come across them
      if !@path_on_choice.nil? && @path_on_choice.relative?
        choice_target_object = choice_target
        if !choice_target_object.nil?
          @path_on_choice = choice_target_object.path
        end
      end

      return @path_on_choice
    end

    def path_on_choice=(value)
      @path_on_choice = value
    end

    def choice_target
      self.resolve_path(@path_on_choice).container
    end

    def path_string_on_choice
      compact_path_string(path_on_choice)
    end

    def path_string_on_choice=(value)
      self.path_on_choice = Path.new(value)
    end

    def flags=(flag)
      self.has_condition = (flag & 0x1) > 0
      self.has_start_content = (flag & 0x2) > 0
      self.has_choice_only_content = (flag & 0x4) > 0
      self.invisible_default = (flag & 0x8) > 0
      self.once_only = (flag & 0x16) > 0
    end

    def to_s
      target_line_number = debug_line_number_of_path(path_on_choice)
      target_string = path_on_choice.to_s

      if !target_line_number.nil?
        target_string = " line #{target_line_number} (#{target_string})"
      end

      return "Choice: -> #{target_string}"
    end
  end
end