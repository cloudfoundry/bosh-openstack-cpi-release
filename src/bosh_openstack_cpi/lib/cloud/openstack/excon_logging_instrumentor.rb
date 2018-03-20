module Bosh::OpenStackCloud
  class ExconLoggingInstrumentor
    REDACTED = '<redacted>'.freeze

    def self.instrument(name, params = {})
      redacted_params = redact(params)

      Bosh::Clouds::Config.logger.debug("#{name} #{redacted_params}")
      yield if block_given?
    end

    def self.redact(params)
      redacted_params = params.dup
      redact_body(redacted_params, 'auth.passwordCredentials.password')
      redact_body(redacted_params, 'server.user_data')
      redact_body(redacted_params, 'auth.identity.password.user.password')
      redact_headers(redacted_params, 'X-Auth-Token')
      redacted_params
    end

    private

    def self.redact_body(params, json_path)
      return unless params.key?(:body) && params[:body].is_a?(String)
      return unless params.key?(:headers) && params[:headers]['Content-Type'] == 'application/json'

      begin
        json_content = JSON.parse(params[:body])
      rescue JSON::ParserError
        return
      end
      json_content = Bosh::Cpi::Redactor.redact!(json_content, json_path)
      params[:body] = JSON.dump(json_content)
    end

    def self.redact_headers(params, property)
      return unless params.key?(:headers)

      headers = params[:headers] = params[:headers].dup

      headers.store(property, REDACTED)
    end

    def self.fetch_property
      ->(hash, property) { hash.fetch(property, {}) }
    end
  end
end
