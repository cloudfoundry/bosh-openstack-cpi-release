module Bosh::OpenStackCloud

  module Helpers

    def self.included(base)
      base.extend(Helpers)
    end

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

    def fail_on_error(errors)
      return if errors.nil? || errors.empty?

      errors.each { |error| @logger.error(error) }

      message = errors.map { |error| error.message }.join("\n")
      prefix = errors.size > 1 ? "Multiple Cloud Errors occurred:\n" : ''

      raise Bosh::Clouds::CloudError.new(prefix + message)
    end

    def catch_error
      result = nil

      if block_given?
        begin
          yield
        rescue => e
          result = e
        end
      end

      result
    end
  end
end
