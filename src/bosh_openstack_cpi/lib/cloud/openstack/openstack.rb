require 'common/common'
require 'fog/openstack/models/model'
require 'fog/openstack/models/image_v2/image'
require 'fog/openstack/models/image_v2/images'

# TODO: remove these patches once https://github.com/fog/fog-openstack/pull/170 is merged
# image_v2 disabled the `identity` method to workaround around a bug
# where image.save would call update instead of create on a new image if the user
# explicitly set an ID.
# The removal of `identity` breaks the `reload` our waiters use for all resources.
# As the CPI does not set ID on create, we can monkeypatch image_v2 to call through
# to original implementation of `identity` until a fix is added upstream.
module FogImagePatch
  def identity
    Fog::Model.instance_method(:identity).bind(self).call
  end
end
Fog::Image::OpenStack::V2::Image.prepend FogImagePatch
# image_v2 also breaks `reload` for images fetched via `images.get(image_id)`
# as the image.collection is nil
module FogImagesPatch
  def find_by_id(id)
    all.find {|image| image.id == id}
  end
  alias_method :get, :find_by_id
end
Fog::Image::OpenStack::V2::Images.prepend FogImagesPatch

# TODO: Monkey Patch Fog, provide PR
module Fog
  module Compute
    class OpenStack
      class Real
        def get_server_port_interfaces(server_id)
          request(
              :expects  => 200,
              :method   => 'GET',
              :path     => "/servers/#{server_id}/os-interface"
          )
        end
      end
    end
  end
end

module Bosh::OpenStackCloud
  class Openstack
    include Helpers

    attr_reader :auth_url, :params, :is_v3

    def self.is_v3(auth_url)
      auth_url.match(/\/v3(?=\/|$)/)
    end

    def initialize(options, connect_retry_options = {})
      @logger = Bosh::Clouds::Config.logger
      @is_v3 = Openstack.is_v3(options['auth_url'])
      unless options['auth_url'].match(/\/tokens$/)
        if is_v3
          options['auth_url'] += '/auth/tokens'
        else
          options['auth_url'] += '/tokens'
        end
      end
      @auth_url = options['auth_url']
      @use_nova_networking = options.fetch('use_nova_networking', false)

      options['connection_options'] ||= {}

      @extra_connection_options = {'instrumentor' => Bosh::OpenStackCloud::ExconLoggingInstrumentor}

      @params = openstack_params(options)
      @connect_retry_options = connect_retry_options
    end

    def use_nova_networking?
      @use_nova_networking
    end

    def compute
      unless @compute
        begin
          Bosh::Common.retryable(@connect_retry_options) do |tries, error|
            @logger.error("Failed #{tries} times, last failure due to: #{error.inspect}") unless error.nil?
            @compute = Fog::Compute.new(params)
          end
        rescue Excon::Errors::SocketError => e
          cloud_error(socket_error_msg + "#{e.message}")
        rescue Bosh::Common::RetryCountExceeded, Excon::Errors::ClientError, Excon::Errors::ServerError => e
          cloud_error("Unable to connect to the OpenStack Compute Service API: #{e.message}. Check task debug log for details.")
        end
      end
      @compute
    end

    def image
      unless @glance
        begin
          Bosh::Common.retryable(@connect_retry_options) do |tries, error|
            @logger.error("Failed #{tries} times, last failure due to: #{error.inspect}") unless error.nil?

            begin
              @glance = Fog::Image::OpenStack::V2.new(params_without_provider)
            rescue Fog::OpenStack::Errors::ServiceUnavailable
              @glance = Fog::Image::OpenStack::V1.new(params_without_provider)
            end
          end
        rescue Excon::Errors::SocketError => e
          cloud_error(socket_error_msg + "#{e.message}")
        rescue Bosh::Common::RetryCountExceeded, Excon::Errors::ClientError, Excon::Errors::ServerError => e
          cloud_error("Unable to connect to the OpenStack Image Service API: #{e.message}. Check task debug log for details.")
        end
      end
      @glance
    end

    ##
    # Creates a client for the OpenStack volume service, or return
    # the existing connection
    #
    #
    def volume
      unless @volume
        begin
          Bosh::Common.retryable(@connect_retry_options) do |tries, error|
            @logger.error("Failed #{tries} times, last failure due to: #{error.inspect}") unless error.nil?
            begin
              @volume = Fog::Volume::OpenStack::V2.new(params_without_provider)
            rescue Fog::OpenStack::Errors::ServiceUnavailable, Fog::Errors::NotFound
              @volume = Fog::Volume::OpenStack::V1.new(params_without_provider)
            end
          end
        rescue Excon::Errors::SocketError => e
          cloud_error(socket_error_msg + "#{e.message}")
        rescue Bosh::Common::RetryCountExceeded, Excon::Errors::ClientError, Excon::Errors::ServerError => e
          cloud_error("Unable to connect to the OpenStack Volume Service API: #{e.message}. Check task debug log for details.")
        end
      end

      @volume
    end

    def network
      unless @network
        begin
          Bosh::Common.retryable(@connect_retry_options) do |tries, error|
            @logger.error("Failed #{tries} times, last failure due to: #{error.inspect}") unless error.nil?
            @network = Fog::Network.new(params)
          end
        rescue Excon::Errors::SocketError => e
          cloud_error(socket_error_msg + "#{e.message}")
        rescue Bosh::Common::RetryCountExceeded, Excon::Errors::ClientError, Excon::Errors::ServerError, Fog::Errors::NotFound => e
          cloud_error("Unable to connect to the OpenStack Network Service API: #{e.message}. Check task debug log for details.")
        end
      end

      @network
    end

    private

    def openstack_params(options)
      {
          :provider => 'OpenStack',
          :openstack_auth_url => options['auth_url'],
          :openstack_username => options['username'],
          :openstack_api_key => options['api_key'],
          :openstack_tenant => options['tenant'],
          :openstack_project_name => options['project'],
          :openstack_domain_name => options['domain'],
          :openstack_region => options['region'],
          :openstack_endpoint_type => options['endpoint_type'],
          :connection_options => options['connection_options'].merge(@extra_connection_options)
      }
    end

    def params_without_provider
      params.reject{ |key, _| key == :provider }
    end

    def socket_error_msg
      "Unable to connect to the OpenStack Keystone API #{params[:openstack_auth_url]}\n"
    end

  end
end
