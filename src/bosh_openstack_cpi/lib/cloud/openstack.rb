module Bosh
  module OpenStackCloud; end
end

require 'fog/openstack'
require 'httpclient'
require 'json'
require 'pp'
require 'set'
require 'tmpdir'
require 'securerandom'
require 'json'
require 'membrane'
require 'netaddr'

require 'common/common'
require 'common/exec'
require 'common/thread_pool'
require 'common/thread_formatter'

require 'bosh/cpi/registry_client'
require 'bosh/cpi/redactor'
require 'cloud'
require 'cloud/openstack/helpers'
require 'cloud/openstack/cloud'
require 'cloud/openstack/cpi_lambda'
require 'cloud/openstack/openstack'
require 'cloud/openstack/tag_manager'

require 'cloud/openstack/network_configurator'
require 'cloud/openstack/loadbalancer_configurator'
require 'cloud/openstack/resource_pool'
require 'cloud/openstack/security_groups'
require 'cloud/openstack/floating_ip'
require 'cloud/openstack/network'
require 'cloud/openstack/private_network'
require 'cloud/openstack/dynamic_network'
require 'cloud/openstack/manual_network'
require 'cloud/openstack/vip_network'
require 'cloud/openstack/volume_configurator'
require 'cloud/openstack/excon_logging_instrumentor'
require 'cloud/openstack/availability_zone_provider'
require 'cloud/openstack/stemcell'
require 'cloud/openstack/stemcell_creator'
require 'cloud/openstack/instance_type_mapper'
require 'cloud/openstack/server_groups'

module Bosh
  module Clouds
    OpenStack = Bosh::OpenStackCloud::Cloud
    Openstack = OpenStack # Alias needed for Bosh::Clouds::Provider.create method
  end
end
