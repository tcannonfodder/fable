module RubyRedInk
  class Error < StandardError; end

  class StoryError < Error
    attr_accessor :use_end_line_number
    alias_method :use_end_line_number?, :use_end_line_number
  end

  def assert!(conditional, error_message = "")
    if !conditional
      raise Error, error_message
    end
  end
end


require "ruby_red_ink/version"
require 'ruby_red_ink/runtime_object'
require "ruby_red_ink/void"

require 'ruby_red_ink/call_stack'
require 'ruby_red_ink/choice'
require 'ruby_red_ink/choice_point'
require 'ruby_red_ink/container'
require 'ruby_red_ink/control_command'
require 'ruby_red_ink/debug_metadata'
require 'ruby_red_ink/divert'
require 'ruby_red_ink/glue'
require 'ruby_red_ink/ink_list'
require 'ruby_red_ink/list_definition'
require 'ruby_red_ink/list_definitions_origin'
require 'ruby_red_ink/native_function_operations'
require 'ruby_red_ink/native_function_call'
require 'ruby_red_ink/observer'
require 'ruby_red_ink/path'
require 'ruby_red_ink/pointer'
require 'ruby_red_ink/profiler'
require 'ruby_red_ink/push_pop_type'
require 'ruby_red_ink/search_result'
require "ruby_red_ink/serializer"
require "ruby_red_ink/state_patch"
require 'ruby_red_ink/story'
require 'ruby_red_ink/variables_state'
require 'ruby_red_ink/story_state'
require 'ruby_red_ink/tag'
require 'ruby_red_ink/value'
require 'ruby_red_ink/variable_assignment'
require 'ruby_red_ink/variable_reference'

