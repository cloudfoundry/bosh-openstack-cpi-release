module Bosh::OpenStackCloud
  class CpiLambda
    CONTEXT_CA_PATH = '/var/vcap/jobs/openstack_cpi/config/cacert_context.pem'

    def self.create(cpi_config, cpi_log, ca_cert_from_config, ca_cert_from_context=CONTEXT_CA_PATH)
      lambda do |context|
        unless cpi_config.has_key?('cloud') && cpi_config['cloud'].has_key?('properties')
          raise "Could not find cloud properties in the configuration"
        end

        cloud_properties = cpi_config['cloud']['properties']

        cloud_properties['cpi_log'] = cpi_log

        # If 'ca_cert' is set we render non-empty `config/openstack.crt`
        set_ca_cert_in_connection_options(cloud_properties, ca_cert_from_config)

        # allow openstack config to be overwritten dynamically by context
        if context && context['cpi_properties']
          cloud_properties['openstack'] = context['cpi_properties']
          set_ca_cert_in_connection_options(cloud_properties, ca_cert_from_context, true)
        end

        Bosh::Clouds::Openstack.new(cloud_properties)
      end
    end

    private
    def self.set_ca_cert_in_connection_options(cloud_properties, ca_cert_path, write_to_disk=false)
      connection_options = cloud_properties['openstack']['connection_options']
      if connection_options && connection_options['ca_cert']
        File.write(ca_cert_path, connection_options['ca_cert']) if write_to_disk
        connection_options['ssl_ca_file'] = ca_cert_path
        connection_options.delete('ca_cert')
      end
    end
  end
end