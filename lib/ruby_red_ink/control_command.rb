module RubyRedInk
  class ControlCommand < RuntimeObject
    COMMANDS = {
      NOT_SET: -1,
      EVALUATION_START: "ev",
      EVALUATION_OUTPUT: "out",
      EVALUATION_END: "/ev",
      DUPLICATE_TOPMOST: "du",
      POP_EVALUATED_VALUE: "pop",
      POP_FUNCTION: "~ret",
      POP_TUNNEL: "->->",
      BEGIN_STRING_EVALUATION_MODE: "str",
      END_STRING_EVALUATION_MODE: "/str",
      NOOP: "nop",
      PUSH_CHOICE_COUNT: "choiceCnt",
      TURNS: "turn",
      TURNS_SINCE: "turns",
      READ_COUNT: "readc",
      RANDOM: "rnd",
      SEED_RANDOM: "srnd",
      VISIT_INDEX: "visit",
      SEQUENCE_SHUFFLE_INDEX: "seq",
      START_THREAD: "thread",
      DONE: "done",
      STORY_END: "end",
      LIST_FROM_INT: "listInt",
      LIST_RANGE: "range",
      LIST_RANDOM: "lrnd",

      GLUE: "<>",
    }.freeze

    LOOKUP = COMMANDS.invert.freeze

    attr_accessor :command_type

    def self.is_control_command?(value)
      LOOKUP.has_key?(value)
    end

    def self.get_control_command(value)
      raise ArgumentError if !is_control_command?(value)
      self.new(value)
    end

    def initialize(command_symbol)
      super()
      self.command_type = LOOKUP[command_symbol]
    end

    def self.is_instance_of?(object, command_type)
      object.is_a?(self) && object.command_type == command_type
    end

    def to_s
      command_type.to_s
    end

    def self.evaluation_start
      self.new(COMMANDS[:EVALUATION_START])
    end

    def self.evaluation_output
      self.new(COMMANDS[:EVALUATION_OUTPUT])
    end

    def self.evaluation_end
      self.new(COMMANDS[:EVALUATION_END])
    end

    def self.duplicate_topmost
      self.new(COMMANDS[:DUPLICATE_TOPMOST])
    end

    def self.pop_evaluated_value
      self.new(COMMANDS[:POP_EVALUATED_VALUE])
    end

    def self.pop_function
      self.new(COMMANDS[:POP_FUNCTION])
    end

    def self.pop_tunnel
      self.new(COMMANDS[:POP_TUNNEL])
    end

    def self.begin_string_evaluation_mode
      self.new(COMMANDS[:BEGIN_STRING_EVALUATION_MODE])
    end

    def self.end_string_evaluation_mode
      self.new(COMMANDS[:END_STRING_EVALUATION_MODE])
    end

    def self.noop
      self.new(COMMANDS[:NOOP])
    end

    def self.push_choice_count
      self.new(COMMANDS[:PUSH_CHOICE_COUNT])
    end

    def self.turns
      self.new(COMMANDS[:TURNS])
    end

    def self.turns_since
      self.new(COMMANDS[:TURNS_SINCE])
    end

    def self.read_count
      self.new(COMMANDS[:READ_COUNT])
    end

    def self.random
      self.new(COMMANDS[:RANDOM])
    end

    def self.seed_random
      self.new(COMMANDS[:SEED_RANDOM])
    end

    def self.visit_index
      self.new(COMMANDS[:VISIT_INDEX])
    end

    def self.sequence_shuffle_index
      self.new(COMMANDS[:SEQUENCE_SHUFFLE_INDEX])
    end

    def self.start_thread
      self.new(COMMANDS[:START_THREAD])
    end

    def self.done
      self.new(COMMANDS[:DONE])
    end

    def self.story_end
      self.new(COMMANDS[:STORY_END])
    end

    def self.list_from_int
      self.new(COMMANDS[:LIST_FROM_INT])
    end

    def self.list_range
      self.new(COMMANDS[:LIST_RANGE])
    end

    def self.list_random
      self.new(COMMANDS[:LIST_RANDOM])
    end

  end
end