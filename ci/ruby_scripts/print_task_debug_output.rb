#!/usr/bin/env ruby
require_relative 'failed_tasks_parser'

cmds = errors_to_bosh_tasks_cmds(ARGF.read)
cmds.each do |cmd|
  puts `#{cmd}`
end
