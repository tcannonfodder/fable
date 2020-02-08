module RubyRedInk
  module ChoicePoint
    class Choice
      attr_accessor :has_condition, :has_start_content, :has_choice_only_content, :is_invisible_default, :once_only, :original_object

      def initialize(original_object)
        self.original_object = original_object
      end

      def path_when_chosen
        original_object["*"]
      end

      def process_bit_flags
        flag = original_object["flg"]
        has_start_content = flag & 0x1
        has_start_content = flag & 0x2
        has_choice_only_content = flag & 0x4
        is_invisible_default = flag & 0x8
        once_only = 0x10
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