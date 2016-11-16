module Bosh::OpenStackCloud
  ##
  # Represents OpenStack dynamic network: where IaaS sets VM's IP
  class DynamicNetwork < PrivateNetwork

    ##
    # Creates a new dynamic network
    #
    # @param [String] name Network name
    # @param [Hash] spec Raw network spec
    def initialize(name, spec)
      super
    end

  end
end
