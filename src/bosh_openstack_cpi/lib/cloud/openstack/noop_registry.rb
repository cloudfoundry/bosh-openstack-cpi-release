
module Bosh::OpenStackCloud
  class NoopRegistry
    include Helpers

    def initialize(endpoint = nil, user = nil, password = nil) end

    def update_settings(instance_id, settings) end

    def read_settings(instance_id)
      {}
    end

    def delete_settings(instance_id) end

    def endpoint() end
  end
end
