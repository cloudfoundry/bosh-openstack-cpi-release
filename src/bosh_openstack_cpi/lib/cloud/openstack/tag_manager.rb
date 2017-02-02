module Bosh::OpenStackCloud
  class TagManager

    MAX_TAG_KEY_LENGTH = 255
    MAX_TAG_VALUE_LENGTH = 255

    def self.tag(taggable, key, value)
      return if key.nil? || value.nil?
      
      trimmed_key, trimmed_value = self.trim(key, value)
      taggable.metadata.update(trimmed_key => trimmed_value)
    end
    
    def self.trim(key, value)
      return if key.nil? || value.nil?
      
      return key[0..(MAX_TAG_KEY_LENGTH - 1)], value[0..(MAX_TAG_VALUE_LENGTH - 1)]
    end
  end
end
