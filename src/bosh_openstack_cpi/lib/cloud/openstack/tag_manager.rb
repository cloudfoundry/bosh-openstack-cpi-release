module Bosh::OpenStackCloud
  class TagManager
    MAX_TAG_KEY_LENGTH = 255
    MAX_TAG_VALUE_LENGTH = 255

    def self.tag_server(server, tags)
      formatted_tags = format(tags)

      server.metadata.update(formatted_tags) unless formatted_tags.empty?
    end

    def self.tag_volume(volume, volume_id, tags)
      formatted_tags = format(tags)

      volume.update_metadata(volume_id, formatted_tags) unless formatted_tags.empty?
    end

    def self.tag_snapshot(snapshot, tags)
      formatted_tags = format(tags)

      snapshot.update_metadata(formatted_tags) unless formatted_tags.empty?
    end

    def self.format(tags)
      tags
        .reject { |key, value| key.nil? || value.nil? }
        .map do |key, value|
          [key.to_s[0..(MAX_TAG_KEY_LENGTH - 1)], value.to_s[0..(MAX_TAG_VALUE_LENGTH - 1)]]
        end
        .to_h
    end
  end
end
