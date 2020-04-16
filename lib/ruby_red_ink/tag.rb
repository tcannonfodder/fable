module RubyRedInk
  class Tag < RuntimeObject
    attr_accessor :text

    def initialize(tag_text)
      self.text = tag_text
    end

    def to_s
      return "# #{self.text}"
    end
  end
end