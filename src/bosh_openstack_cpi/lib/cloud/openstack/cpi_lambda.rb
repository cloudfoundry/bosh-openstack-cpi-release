module Bosh::OpenStackCloud
  class CpiLambda
    def self.create(cpi_config, ssl_ca_file, cpi_log)
      lambda do |context|
        unless cpi_config.has_key?('cloud') && cpi_config['cloud'].has_key?('properties')
          raise "Could not find cloud properties in the configuration"
        end

        cloud_properties = cpi_config['cloud']['properties']

        cloud_properties['cpi_log'] = cpi_log
        connection_options = cloud_properties['openstack']['connection_options']
        # If 'ca_cert' is set we render non-empty `config/openstack.crt`
        if connection_options && connection_options['ca_cert']
          connection_options['ssl_ca_file'] = ssl_ca_file
          connection_options.delete('ca_cert')
        end

        # allow openstack config to be overwritten dynamically by context
        if context && context['cpi_properties']
          cloud_properties['openstack'] = context['cpi_properties']
        end

        Bosh::Clouds::Openstack.new(cloud_properties)
      end
    end
  end
end