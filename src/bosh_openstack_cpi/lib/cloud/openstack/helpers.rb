module Bosh::OpenStackCloud

  module Helpers

    def self.included(base)
      base.extend(Helpers)
    end

    MAX_RETRIES = 10 # Max number of retries
    DEFAULT_RETRY_TIMEOUT = 3 # Default timeout before retrying a call (in seconds)

    ##
    # Raises CloudError exception
    #
    # @param [String] message Message about what went wrong
    # @param [Exception] exception Exception to be logged (optional)
    def cloud_error(message, exception = nil)
      @logger.error(message) if @logger
      @logger.error(exception) if @logger && exception
      raise Bosh::Clouds::CloudError, message
    end

    def with_openstack
      retries = 0
      begin
        yield

      rescue Excon::Errors::RequestEntityTooLarge => e
        message = "OpenStack API Request Entity Too Large error: \nCheck task debug log for details."
        overlimit = parse_openstack_response(e.response, "overLimit", "overLimitFault")

        if overlimit
          message.insert(46, overlimit["message"])
          details = "#{overlimit["message"]} - #{overlimit["details"]}"

          if retries < MAX_RETRIES
            wait_time = overlimit["retryAfter"] || e.response.headers["Retry-After"] || DEFAULT_RETRY_TIMEOUT
            @logger.debug("OpenStack API Over Limit (#{details}), waiting #{wait_time} seconds before retrying") if @logger
            sleep(wait_time.to_i)
            retries += 1
            retry
          end
        else
          message.insert(46, e.response.body)
        end
        cloud_error(message, e)

      rescue Excon::Errors::ServiceUnavailable => e
        unless retries >= MAX_RETRIES
          retries += 1
          @logger.debug("OpenStack API Service Unavailable error, retrying (#{retries})") if @logger
          sleep(DEFAULT_RETRY_TIMEOUT)
          retry
        end
        cloud_error('OpenStack API Service Unavailable error. Check task debug log for details.', e)

      rescue Excon::Errors::BadRequest => e
        body = parse_openstack_response_body(e.response.body)
        message = determine_message(body)
        cloud_error("OpenStack API Bad Request#{message}. Check task debug log for details.", e)

      rescue Excon::Errors::Conflict => e
        body = parse_openstack_response_body(e.response.body)
        message = determine_message(body)
        cloud_error("OpenStack API Conflict#{message}. Check task debug log for details.", e)

      rescue Excon::Errors::InternalServerError => e
        unless retries >= MAX_RETRIES
          retries += 1
          @logger.debug("OpenStack API Internal Server error, retrying (#{retries})") if @logger
          sleep(DEFAULT_RETRY_TIMEOUT)
          retry
        end
        cloud_error('OpenStack API Internal Server error. Check task debug log for details.', e)

      rescue Fog::Errors::NotFound => e
        cloud_error("OpenStack API service not found error: #{e.message}\nCheck task debug log for details.", e)

      end
    end

    ##
    # Parses and look ups for keys in an OpenStack response
    #
    # @param [Excon::Response] response Response from OpenStack API
    # @param [Array<String>] keys Keys to look up in response
    # @return [Hash] Contents at the first key found, or nil if not found
    def parse_openstack_response(response, *keys)
      json_body = parse_openstack_response_body(response.body)
      key = keys.detect { |k| json_body.has_key?(k)} if (json_body && !json_body.empty?)
      json_body[key] if key
    end

    private

    def openstack_fault_message(resource)
      openstack_message = ''
      if resource.respond_to?(:fault) && (fault = resource.fault)
        openstack_message = "\n#{fault['message']}" if fault['message']
        openstack_message += fault['details'] if fault['details']
      end
      openstack_message
    end

    def determine_message(body)
      hash_with_msg_property = proc { |k, v| (v.is_a? Hash) && v['message'] }

      body ||= {}
      _, value = body.find &hash_with_msg_property
      value ? " (#{value['message']})" : ''
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
