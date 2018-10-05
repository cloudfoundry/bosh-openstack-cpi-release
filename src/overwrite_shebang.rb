#!/usr/bin/env ruby

bin = File.readlines ARGV[0]
bin[0] = "#!#{ARGV[1]}\n"

File.open ARGV[0], 'w' do |fp|
  fp.puts bin.join
end
