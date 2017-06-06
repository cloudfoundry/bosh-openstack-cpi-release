#!/usr/bin/env ruby
require 'json'
require_relative 'failed_tasks_parser'

tasks = JSON.parse(ARGF.read)

errors_to_bosh_tasks_cmds(tasks)
  .each { |cmd| puts `#{cmd}` }
