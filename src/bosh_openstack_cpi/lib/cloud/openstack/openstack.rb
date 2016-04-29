require 'common/common'

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

      options['connection_options'] ||= {}

      @extra_connection_options = {'instrumentor' => Bosh::OpenStackCloud::ExconLoggingInstrumentor}

      @params = openstack_params(options)
      @connect_retry_options = connect_retry_options
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
            @glance = Fog::Image.new(params)
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
      # the existing connectuion
      #
      #
    def volume
      unless @volume
        begin
          Bosh::Common.retryable(@connect_retry_options) do |tries, error|
            @logger.error("Failed #{tries} times, last failure due to: #{error.inspect}") unless error.nil?
            @volume ||= Fog::Volume::OpenStack::V1.new(params)
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
        rescue Bosh::Common::RetryCountExceeded, Excon::Errors::ClientError, Excon::Errors::ServerError => e
          cloud_error("Unable to connect to the OpenStack Network Service API: #{e.message}. Check task debug log for details.")
        end
      end

      @network
    end

    def metadata

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

    def socket_error_msg
      "Unable to connect to the OpenStack Keystone API #{params[:openstack_auth_url]}\n"
    end

  end
end