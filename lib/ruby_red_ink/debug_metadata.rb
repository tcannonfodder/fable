module RubyRedInk
  class DebugMetadata
    attr_accessor :start_line_number, :end_line_number, :file_name, :source_name

    def to_s
      if !file_name.nil?
        "line #{start_line_number} of #{file_name}"
      else
        "line #{start_line_number}"
      end
    end
  end
end