$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "ruby_red_ink"

Bundler.require(:default, :development)

require "minitest/autorun"
require 'json'

def load_json_export(filepath = "test/fixtures/the-intercept.js.json")
  JSON.parse(File.read(filepath))
end

def build_container(object)
  RubyRedInk::Container.new(object)
end