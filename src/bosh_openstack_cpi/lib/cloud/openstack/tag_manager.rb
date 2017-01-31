module Bosh::OpenStackCloud
  class TagManager

    MAX_TAG_KEY_LENGTH = 255
    MAX_TAG_VALUE_LENGTH = 255

    def self.tag(taggable, key, value)
      return if key.nil? || value.nil?
      trimmed_key = key[0..(MAX_TAG_KEY_LENGTH - 1)]
      trimmed_value = value[0..(MAX_TAG_VALUE_LENGTH - 1)]
      taggable.metadata.update(trimmed_key => trimmed_value)
    end

    def self.tag_and_save(taggable, key, value)
      self.tag(taggable, key, value)
      taggable.save
    end
  end
end
