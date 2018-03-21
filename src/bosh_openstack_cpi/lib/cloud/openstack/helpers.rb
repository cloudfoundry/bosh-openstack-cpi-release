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
      raise_error(Bosh::Clouds::CloudError, exception, message)
    end

    def not_supported_error(message, exception = nil)
      raise_error(Bosh::Clouds::NotSupported, exception, message)
    end

    def fail_on_error(*errors)
      errors = errors.compact
      return if errors.empty?

      errors.each do |error|
        @logger.error(error)
        @logger.error(error.backtrace)
      end

      message = errors.map(&:message).join("\n")
      prefix = errors.size > 1 ? "Multiple cloud errors occurred:\n" : ''

      raise Bosh::Clouds::CloudError, prefix + message
    end

    def catch_error(prefix = nil)
      result = nil

      return nil unless block_given?
      begin
        yield
      rescue StandardError => e
        result = if prefix
                   wrap_error(e, prefix)
                 else
                   e
        end
      end

      result
    end

    private

    def raise_error(error_class, exception, message)
      @logger&.error(message)
      @logger.error(exception) if @logger && exception
      raise error_class, message
    end

    def wrap_error(error, prefix)
      wrapped_error = error.class.new("#{prefix}: #{error.message}")
      wrapped_error.set_backtrace(error.backtrace)
      wrapped_error
    end
  end
end
