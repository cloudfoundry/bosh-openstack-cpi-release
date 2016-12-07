require 'common/common'
require 'fog/image/openstack/v2/models/image'
require 'fog/image/openstack/v2/models/images'

# TODO: remove these patches once https://github.com/fog/fog-openstack/pull/246 is merged
# image_v2 breaks `reload` for images fetched via `images.get(image_id)` which
# throws a NotFound exception instead of returning `nil`
module FogImagesPatch
  def find_by_id(id)
    super
  rescue Fog::Image::OpenStack::NotFound
    nil
  end
  alias_method :get, :find_by_id
end
Fog::Image::OpenStack::V2::Images.prepend FogImagesPatch

module Bosh::OpenStackCloud
  class Openstack
    include Helpers

    attr_reader :auth_url, :params, :is_v3

    def self.is_v3(auth_url)
      auth_url.match(/\/v3(?=\/|$)/)
    end

    def initialize(options, retry_options_overwrites = {})
      @logger = Bosh::Clouds::Config.logger
      @is_v3 = Openstack.is_v3(options['auth_url'])

      @auth_url = build_auth_url(options['auth_url'])

      @use_nova_networking = options.fetch('use_nova_networking', false)
      if @use_nova_networking
        @logger.debug("Property 'use_nova_networking' is set to true. Using Nova networking APIs instead of Neutron APIs.")
      end

      options['connection_options'] ||= {}

      @extra_connection_options = {'instrumentor' => Bosh::OpenStackCloud::ExconLoggingInstrumentor}

      @params = openstack_params(options)
      @retry_options = {
        sleep: 1,
        tries: 5,
        on: [Excon::Errors::GatewayTimeout, Excon::Errors::SocketError],
      }.merge(retry_options_overwrites)
    end

    def use_nova_networking?
      @use_nova_networking
    end

    def compute
      unless @compute
        begin
          Bosh::Common.retryable(@retry_options) do |tries, error|
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
          Bosh::Common.retryable(@retry_options) do |tries, error|
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
          Bosh::Common.retryable(@retry_options) do |tries, error|
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
          Bosh::Common.retryable(@retry_options) do |tries, error|
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
          :openstack_auth_url => auth_url,
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
      "Unable to connect to the OpenStack Keystone API #{auth_url}\n"
    end

    def remove_url_trailing_slash(url)
      if url.end_with?('/')
        url[0..-2]
      else
        url
      end
    end

    def append_url_sufix(url)
      unless url.match(/\/tokens$/)
        url += '/auth' if @is_v3
        url += '/tokens'
      end

      url
    end

    def build_auth_url(url)
      url = remove_url_trailing_slash(url)
      append_url_sufix(url)
    end

  end
end
