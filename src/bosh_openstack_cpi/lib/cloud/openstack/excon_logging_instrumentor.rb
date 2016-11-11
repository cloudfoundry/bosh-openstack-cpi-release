module Bosh::OpenStackCloud
  class ExconLoggingInstrumentor

    REDACTED = '<redacted>'

    def self.instrument(name, params = {})
      params = apply(params.dup, [
          redact_from_body('auth.passwordCredentials.password'),
          redact_from_body('auth.identity.password.user.password'),
          redact_from_headers('X-Auth-Token')
      ])

      Bosh::Clouds::Config.logger.debug("#{name} #{params}")
      if block_given?
        yield
      end
    end

    private

    def self.apply(params, redactions)
      redactions.reduce(params) do |params, redaction|
        redaction.call(params)
      end
    end

    def self.redact_from_body(json_path)
      -> (params) {
        return params unless params.has_key?(:body) && params[:body].is_a?(String)

        json_content = JSON.parse(params[:body])

        properties = json_path.split('.')
        property_to_redact = properties.pop

        properties.reduce(json_content, &fetch_property).store(property_to_redact, REDACTED)

        params[:body] = JSON.dump(json_content)
        params
      }
    end

    def self.redact_from_headers(property)
      -> (params) {
        return params unless params.has_key?(:headers)

        headers = params[:headers] = params[:headers].dup

        headers.store(property, REDACTED)
        params
      }
    end

    def self.fetch_property
      -> (hash, property) { hash.fetch(property, {})}
    end

  end
end
