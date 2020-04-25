require 'rubygems'
require 'bundler/setup'
Bundler.require(:default, :development)

require 'fable'

require 'highline'

# Basic usage

cli = HighLine.new

## Using colored indices on Menus

HighLine::Menu.index_color   = :rgb_77bbff # set default index color

cli.choose do |menu|
  # menu.index_color  = :rgb_999999      # override default color of index
                                       # you can also use constants like :blue
  menu.prompt = "Please choose your favorite programming language?  "
  menu.choice(:ruby) { cli.say("Good choice!") }
  menu.choices(:python, :perl) { cli.say("Not from around here, are you?") }
end