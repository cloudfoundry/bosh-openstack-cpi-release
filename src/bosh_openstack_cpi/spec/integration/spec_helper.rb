require 'spec_helper'
require 'webmock/rspec'
require_relative './integration_config'
require 'cloud'
require 'tempfile'
require 'logger'
require 'ostruct'

RSpec.configure do |config|
  config.before(:all) { WebMock.allow_net_connect! }
end

def remove_server_groups(openstack)
  openstack.compute.server_groups.all.each do |server_group|
    openstack.compute.delete_server_group(server_group.id)
  end
end

def upload_stemcell(cpi, stemcell_path)
  stemcell_manifest = Psych.load_file(File.join(stemcell_path, 'stemcell.MF'))
  stemcell_id = cpi.create_stemcell(File.join(stemcell_path, 'image'), stemcell_manifest['cloud_properties'])
  [stemcell_id, stemcell_manifest]
end
