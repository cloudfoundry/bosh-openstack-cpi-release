#!/usr/bin/env ruby
require_relative 'failed_tasks_parser'

tasks = ARGF.read

puts tasks

cmds = errors_to_bosh_tasks_cmds(tasks)
cmds.each do |cmd|
  puts `#{cmd}`
end
