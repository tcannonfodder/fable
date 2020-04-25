module Fable
  class Choice < RuntimeObject
    # The main text presented to the player for this choice
    attr_accessor :text


    # Get the path to the original choice point - where was this choice
    # defined in the story?
    attr_accessor :source_path

    # The original index into current_choices list on the Story when
    # this choice was generated, for convenience
    attr_accessor :index

    attr_accessor :target_path, :thread_at_generation, :original_thread_index,
      :invisible_default

    alias_method :invisible_default?, :invisible_default

    # The target path that the story should be diverted to
    # if the choice is chosen
    def path_string_on_choice
      return self.target_path.to_s
    end

    def path_string_on_choice=(value)
      self.target_path = Path.new(value)
      value
    end
  end
end