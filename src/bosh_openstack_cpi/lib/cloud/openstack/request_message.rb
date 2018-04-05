module Bosh::OpenStackCloud
  class RequestMessage
    def initialize(params)
      @params = params
    end

    def format
      params = @params.dup
      params.delete(:ciphers)
      params.delete(:connection)
      params.delete(:__construction_args)
      params.delete(:instrumentor)
      params.delete(:middlewares)
      params.delete(:uri_parser)
      params.delete(:stack)
      hostname = params.delete(:hostname)
      method = params.delete(:method)
      protocol = params.delete(:scheme)
      port = params.delete(:port)
      path = params.delete(:path)
      headers = params.delete(:headers)
      body = params.delete(:body) || 'null'
      "#{method} #{protocol}://#{hostname}:#{port}#{path} params: #{params.to_json} headers: #{headers.to_json} body: #{body}"
    end
  end
end
