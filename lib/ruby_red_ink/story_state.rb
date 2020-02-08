module RubyRedInk
  class EvaluationStack
    attr_accessor :state

    def initialize
      self.state = {}
    end
  end
end