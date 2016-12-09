module Bosh::OpenStackCloud
  class Redactor

    REDACTED = '<redacted>'

    def self.clone_and_redact(hash, path)
      hash = clone(hash)
      if hash.nil?
        hash
      else
        redact(hash, path)
      end
    end

    def self.redact(hash, json_path)
      properties = json_path.split('.')
      property_to_redact = properties.pop

      target_hash = properties.reduce(hash, &fetch_property)
      target_hash.store(property_to_redact, REDACTED) if target_hash.has_key? property_to_redact

      hash
    end

    private

    def self.clone(hash)
      JSON.parse(hash.to_json)
    rescue
      nil
    end

    def self.fetch_property
      -> (hash, property) { hash.fetch(property, {})}
    end

  end
end
