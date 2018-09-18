require 'common/common'

module Bosh::OpenStackCloud
  class Openstack
    include Helpers

    DEFAULT_STATE_TIMEOUT = 300 # Default timeout for target state (in seconds)
    MAX_RETRIES = 10 # Max number of retries
    DEFAULT_RETRY_TIMEOUT = 3 # Default timeout before retrying a call (in seconds)

    attr_reader :auth_url, :params, :is_v3, :state_timeout

    def self.is_v3(auth_url)
      auth_url.match(/\/v3(?=\/|$)/)
    end

    def initialize(options, retry_options_overwrites = {}, extra_connection_options = { 'instrumentor' => Bosh::OpenStackCloud::ExconLoggingInstrumentor })
      @logger = Bosh::Clouds::Config.logger
      @is_v3 = Openstack.is_v3(options['auth_url'])

      @auth_url = build_auth_url(options['auth_url'])

      @use_nova_networking = options.fetch('use_nova_networking', false)
      if @use_nova_networking
        @logger.debug("Property 'use_nova_networking' is set to true. Using Nova networking APIs instead of Neutron APIs.")
      end

      options['connection_options'] ||= {}

      @extra_connection_options = extra_connection_options
      @state_timeout = options['state_timeout'] || DEFAULT_STATE_TIMEOUT
      @wait_resource_poll_interval = options['wait_resource_poll_interval']

      @params = openstack_params(options)
      @retry_options = {
        sleep: 1,
        tries: 5,
        on: [Excon::Error::GatewayTimeout, Excon::Error::Socket],
      }.merge(retry_options_overwrites)
    end

    def with_openstack(retryable: false, ignore_not_found: false)
      retries = 0
      retryable_errors = [Excon::Error::Timeout,
                          Excon::Error::Socket,
                          Excon::Error::ServiceUnavailable,
                          Excon::Error::InternalServerError]
      begin
        yield
      rescue Excon::Error::RequestEntityTooLarge => e
        overlimit = parse_openstack_response(e.response, 'overLimit', 'overLimitFault')

        raise_openstack_error(e, format_error(e, e.response.body)) unless overlimit
        raise_openstack_error(e, format_error(e, overlimit['message'])) unless retries < MAX_RETRIES

        wait_time = overlimit['retryAfter'] || e.response.headers['Retry-After'] || DEFAULT_RETRY_TIMEOUT
        overlimit_msg = "Over Limit: #{overlimit['message']} - #{overlimit['details']}"
        log_retry_error(e, retries, overlimit_msg, wait_time)
        sleep(wait_time.to_i)
        retries += 1
        retry
      rescue Fog::Errors::NotFound => e
        raise_openstack_error(e) unless ignore_not_found
        @logger.debug("Suppressed 'not found' error message: #{e.message}")
      rescue Excon::Error::BadRequest, Excon::Error::Conflict, Excon::Error::Forbidden => e
        raise_openstack_error(e, format_error_body(e))
      rescue *retryable_errors => e
        raise_openstack_error(e) unless retries < MAX_RETRIES &&
                                        (dns_problem?(e) || connectivity_problem?(e) && retryable || server_problem?(e))

        retries += 1
        log_retry_error(e, retries)
        sleep(DEFAULT_RETRY_TIMEOUT)
        retry
      end
    end

    def project_name
      is_v3 ? params[:openstack_project_name] : params[:openstack_tenant]
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
        rescue Excon::Error::Socket => e
          cloud_error(socket_error_msg + e.message.to_s)
        rescue Bosh::Common::RetryCountExceeded, Excon::Error::Client, Excon::Error::Server => e
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
        rescue Excon::Error::Socket => e
          cloud_error(socket_error_msg + e.message.to_s)
        rescue Bosh::Common::RetryCountExceeded, Excon::Error::Client, Excon::Error::Server => e
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
        rescue Excon::Error::Socket => e
          cloud_error(socket_error_msg + e.message.to_s)
        rescue Bosh::Common::RetryCountExceeded, Excon::Error::Client, Excon::Error::Server => e
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
        rescue Excon::Error::Socket => e
          cloud_error(socket_error_msg + e.message.to_s)
        rescue Bosh::Common::RetryCountExceeded, Excon::Error::Client, Excon::Error::Server, Fog::Errors::NotFound => e
          cloud_error("Unable to connect to the OpenStack Network Service API: #{e.message}. Check task debug log for details.")
        end
      end

      @network
    end

    ##
    # Waits for a resource to be on a target state
    #
    # @param [Fog::Model] resource Resource to query
    # @param [Array<Symbol>] target_state Resource's state desired
    # @param [Symbol] state_method Resource's method to fetch state
    # @param [Boolean] ignore_not_found true if resource could be not found
    def wait_resource(resource, target_state, state_method = :status, ignore_not_found = false)
      started_at = Time.now
      desc = resource.class.name.split('::').last.to_s + ' `' + resource.id.to_s + "'"
      target_state = Array(target_state)

      loop do
        duration = Time.now - started_at

        cloud_error("Timed out waiting for #{desc} to be #{target_state.join(', ')}") if duration > @state_timeout

        @logger.debug("Waiting for #{desc} to be #{target_state.join(', ')} (#{duration}s)")

        # If resource reload is nil, perhaps it's because resource went away
        # (ie: a destroy operation). Don't raise an exception if this is
        # expected (ignore_not_found).
        if with_openstack(retryable: true) { resource.reload.nil? }
          break if ignore_not_found
          cloud_error("#{desc}: Resource not found")
        else
          state = with_openstack { resource.send(state_method).downcase.to_sym }
        end

        # This is not a very strong convention, but some resources
        # have 'error', 'failed' and 'killed' states, we probably don't want to keep
        # waiting if we're in these states. Alternatively we could introduce a
        # set of 'loop breaker' states but that doesn't seem very helpful
        # at the moment
        if state == :error || state == :failed || state == :killed
          cloud_error("#{desc} state is #{state}, expected #{target_state.join(', ')}#{openstack_fault_message(resource)}")
        end

        break if target_state.include?(state)

        sleep(@wait_resource_poll_interval)
      end

      total = Time.now - started_at
      @logger.info("#{desc} is now #{target_state.join(', ')}, took #{total}s")
    end

    ##
    # Parses and look ups for keys in an OpenStack response
    #
    # @param [Excon::Response] response Response from OpenStack API
    # @param [Array<String>] keys Keys to look up in response
    # @return [Hash] Contents at the first key found, or nil if not found
    def parse_openstack_response(response, *keys)
      json_body = parse_openstack_response_body(response.body)
      key = keys.detect { |k| json_body.key?(k) } if json_body && !json_body.empty?
      json_body[key] if key
    end

    private

    def dns_problem?(e)
      e.is_a?(Excon::Error::Socket) && e.message =~ /getaddrinfo/
    end

    def connectivity_problem?(e)
      e.is_a?(Excon::Error::Timeout) || e.is_a?(Excon::Error::Socket)
    end

    def server_problem?(e)
      e.is_a?(Excon::Error::ServiceUnavailable) || e.is_a?(Excon::Error::InternalServerError)
    end

    def format_error_body(e)
      body = parse_openstack_response_body(e.response.body)
      msg = determine_message(body)
      format_error(e, msg)
    end

    def format_error(e, msg = nil)
      error_name = e.class.name.split('::').last
      [error_name, e.message, msg].uniq.reject(&:nil?).reject(&:empty?).join(' ')
    end

    def raise_openstack_error(e, msg = nil)
      msg ||= format_error(e)
      error_message = "OpenStack API #{msg}.\nCheck task debug log for details."
      cloud_error(error_message, e)
    end

    def log_retry_error(e, retry_index, msg = nil, wait_time = DEFAULT_RETRY_TIMEOUT)
      msg ||= format_error(e)
      retry_msg = "OpenStack API #{msg}, retrying (#{retry_index}/#{MAX_RETRIES}) after #{wait_time} seconds."
      @logger.info(retry_msg)
    end

    def openstack_params(options)
      {
        provider: 'OpenStack',
        openstack_auth_url: auth_url,
        openstack_username: options['username'],
        openstack_api_key: options['api_key'],
        openstack_tenant: options['tenant'],
        openstack_project_name: options['project'],
        openstack_domain_name: options['domain'],
        openstack_region: options['region'],
        openstack_endpoint_type: options['endpoint_type'],
        connection_options: options['connection_options'].merge(@extra_connection_options),
      }
    end

    def params_without_provider
      params.reject { |key, _| key == :provider }
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
      unless url.match?(/\/tokens$/)
        url += '/auth' if @is_v3
        url += '/tokens'
      end

      url
    end

    def build_auth_url(url)
      url = remove_url_trailing_slash(url)
      append_url_sufix(url)
    end

    def openstack_fault_message(resource)
      openstack_message = ''
      if resource.respond_to?(:fault) && (fault = resource.fault)
        openstack_message = "\n#{fault['message']}" if fault['message']
        openstack_message += fault['details'] if fault['details']
      end
      openstack_message
    end

    def determine_message(body)
      hash_with_msg_property = proc { |_k, v| (v.is_a? Hash) && v['message'] }

      body ||= {}
      _, value = body.find &hash_with_msg_property
      value ? "(#{value['message']})" : ''
    end

    def parse_openstack_response_body(body)
      unless body.empty?
        begin
          return JSON.parse(body)
        rescue JSON::ParserError
          # do nothing
        end
      end
      nil
    end
  end
end
