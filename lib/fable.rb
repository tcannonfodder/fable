module Fable
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


require "fable/version"
require 'fable/runtime_object'
require "fable/void"

require 'fable/call_stack'
require 'fable/choice'
require 'fable/choice_point'
require 'fable/container'
require 'fable/control_command'
require 'fable/debug_metadata'
require 'fable/divert'
require 'fable/glue'
require 'fable/ink_list'
require 'fable/list_definition'
require 'fable/list_definitions_origin'
require 'fable/native_function_operations'
require 'fable/native_function_call'
require 'fable/observer'
require 'fable/path'
require 'fable/pointer'
require 'fable/profiler'
require 'fable/push_pop_type'
require 'fable/search_result'
require "fable/serializer"
require "fable/state_patch"
require 'fable/story'
require 'fable/variables_state'
require 'fable/story_state'
require 'fable/tag'
require 'fable/value'
require 'fable/variable_assignment'
require 'fable/variable_reference'

