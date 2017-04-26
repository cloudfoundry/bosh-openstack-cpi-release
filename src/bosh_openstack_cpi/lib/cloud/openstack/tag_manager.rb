module Bosh::OpenStackCloud
  class TagManager

    MAX_TAG_KEY_LENGTH = 255
    MAX_TAG_VALUE_LENGTH = 255

    def self.tag_server(server, tags)
      trimmed_tags = trim(reject_nil_tags(tags))

      server.metadata.update(trimmed_tags) unless trimmed_tags.empty?
    end

    def self.tag_volume(volume, volume_id, tags)
      trimmed_tags = trim(reject_nil_tags(tags))

      volume.update_metadata(volume_id, trimmed_tags) unless trimmed_tags.empty?
    end

    def self.reject_nil_tags(tags)
      tags.reject { |key, value| key.nil? || value.nil? }
    end

    def self.trim(tags)
      tags.map do |key, value|
        [key[0..(MAX_TAG_KEY_LENGTH - 1)], value[0..(MAX_TAG_VALUE_LENGTH - 1)]]
      end.to_h
    end
  end
end
