require 'spec_helper'
require 'webmock/rspec'

RSpec.configure do |config|
  config.before(:all) { WebMock.allow_net_connect! }
end
