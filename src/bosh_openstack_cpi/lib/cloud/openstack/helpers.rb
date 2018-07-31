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

    def fail_on_error(*error_wrappers)
      error_wrappers = error_wrappers.compact
      return if error_wrappers.empty?

      error_wrappers.each do |error_wrapper|
        @logger.error(error_wrapper.error)
        @logger.error(error_wrapper.error.backtrace)
      end

      message = error_wrappers.map(&:message).join("\n")
      prefix = error_wrappers.size > 1 ? "Multiple cloud errors occurred:\n" : ''

      raise Bosh::Clouds::CloudError, prefix + message
    end

    def catch_error(prefix = nil)
      return nil unless block_given?
      begin
        yield
      rescue StandardError => e
        return ErrorWrapper.new(e, prefix)
      end

      nil
    end

    private

    class ErrorWrapper
      attr_reader :error, :prefix

      def initialize(error, prefix=nil)
        @error = error
        @prefix = prefix
      end

      def message
        if prefix
          "#{prefix}: #{error.message}"
        else
          error.message
        end
      end
    end


    def raise_error(error_class, exception, message)
      @logger&.error(message)
      @logger.error(exception) if @logger && exception
      raise error_class, message
    end
  end
end
