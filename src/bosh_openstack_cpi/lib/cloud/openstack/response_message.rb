module Bosh::OpenStackCloud
  class ResponseMessage
    def initialize(params)
      @params = params.dup
    end

    def format
      params = @params.dup
      body = params.delete(:body)
      path = params.delete(:path)
      headers = params.delete(:headers)
      status_line = params.delete(:status_line)&.chomp
      params.delete(:cookies)
      params.delete(:reason_phrase)
      params.delete(:status)
      "#{status_line} #{path} params: #{params.to_json} headers: #{headers.to_json} body: #{body}"
    end
  end
end
