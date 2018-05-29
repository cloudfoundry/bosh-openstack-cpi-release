module Bosh::OpenStackCloud
  class VmCreator
    include Helpers

    def initialize(network_configurator, server, az_provider, cloud_properties, agent_settings, create_vm_params)
      @network_configurator = network_configurator
      @server = server
      @az_provider = az_provider

      @cloud_properties = cloud_properties
      @create_vm_params = create_vm_params
      @agent_settings = agent_settings

      @logger = Bosh::Clouds::Config.logger
    end

    def perform
      if @az_provider.use_multiple_azs?(@cloud_properties)
        create_vm_multiple_azs
      else
        create_vm_single_az
      end
    end

    private

    def create_vm_single_az
      availability_zone = @az_provider.select(@disk_locality, @cloud_properties['availability_zone'])
      create_vm_in_az(availability_zone)
    end

    def create_vm_multiple_azs
      availability_zones = @az_provider.select_azs(@cloud_properties)
      availability_zones.each_with_index do |az, i|
        begin
          return create_vm_in_az(az)
        rescue => e
          if az == availability_zones.last
            @logger.error("Failed to create VM in AZ '#{az}' with error '#{e}' after #{i + 1} retries. No AZs left to retry.")
            raise e
          else
            @logger.warn("Failed to create VM in AZ '#{az}' with error '#{e}', retrying in a different AZ")
          end
        end
      end
    end

    def create_vm_in_az(availability_zone)
      @create_vm_params[:availability_zone] = availability_zone if availability_zone
      @server.create(
        @agent_settings,
        @network_configurator,
        @cloud_properties,
        @create_vm_params
      )
    end
  end
end
