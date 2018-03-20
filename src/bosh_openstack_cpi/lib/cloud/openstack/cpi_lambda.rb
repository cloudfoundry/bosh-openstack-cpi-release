module Bosh::OpenStackCloud
  class CpiLambda
    def self.create(cpi_config, cpi_log, ca_cert_from_config, ca_cert_from_context)
      lambda do |context|
        unless cpi_config.key?('cloud') && cpi_config['cloud'].key?('properties')
          raise 'Could not find cloud properties in the configuration'
        end

        cloud_properties = cpi_config['cloud']['properties']
        cloud_properties['cpi_log'] = cpi_log

        # If 'ca_cert' is set in job config we render non-empty `config/openstack.crt` (excon needs it as a file)
        connection_options = cloud_properties['openstack']['connection_options']
        connection_options['ssl_ca_file'] = ca_cert_from_config if connection_options&.delete('ca_cert')

        # allow openstack config to be overwritten dynamically by context
        cloud_properties['openstack'].merge!(context)

        # write ca cert to disk if given in context
        connection_options = cloud_properties['openstack']['connection_options']
        if connection_options && (ca_cert = connection_options.delete('ca_cert'))
          File.write(ca_cert_from_context, ca_cert)
          connection_options['ssl_ca_file'] = ca_cert_from_context
        end

        Bosh::Clouds::Openstack.new(cloud_properties)
      end
    end
  end
end
