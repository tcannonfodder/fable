module RubyRedInk
  module ChoicePoint
    class Choice
      attr_accessor :has_condition,
        :has_start_content, :has_choice_only_content,
        :is_invisible_default,
        :once_only, :original_object,
        :start_content, :choice_only_content,
        :thread_at_generation

      def initialize(original_object)
        self.original_object = original_object
        process_bit_flags
      end

      def path_when_chosen
        original_object["*"]
      end

      def process_bit_flags
        flag = original_object["flg"]
        self.has_start_content = (flag & 0x1) > 0
        self.has_start_content = (flag & 0x2) > 0
        self.has_choice_only_content = (flag & 0x4) > 0
        self.is_invisible_default = (flag & 0x8) > 0
        self.once_only = (flag & 0x10) > 0
      end

      def has_condition?
        has_condition
      end

      def has_start_content?
        has_start_content
      end

      def has_choice_only_content?
        has_choice_only_content
      end

      def is_invisible_default?
        is_invisible_default
      end

      def once_only?
        once_only
      end
    end
  end
end