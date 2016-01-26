require 'json'

def target_service(request, catalog)
  url = /(http|https):\/\/#{request[:host]}:#{request[:port]}/
  catalog_entry = catalog['access']['serviceCatalog'].select do |catalog_entry|
    catalog_entry['endpoints'].any? { |endpoint| endpoint['publicURL'] =~ url }
  end
  if catalog_entry.empty?
    puts "nothing found for url '#{url}'"
  else

    {
        type: catalog_entry[0]['type'],
        name: catalog_entry[0]['name']
    }
  end
end

def scrub_random_body_value!(request, key)
  request[:body].gsub!(/"#{key}":\".*?\"/, "\"#{key}\":\"<#{key}>\"")
end

def scrub_random_values!(requests)
  requests.each do |request|
    tenant_id_regex = /[a-fA-F0-9]{32}/
    tenant_id_alternative_regex = /p-[a-fA-F0-9]{9}/
    resource_id_regex = /[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}/

    request[:path].gsub!(tenant_id_regex, '<tenant_id>')
    request[:path].gsub!(tenant_id_alternative_regex, '<tenant_id>')
    request[:path].gsub!(resource_id_regex, '<resource_id>')
    # life cycle test uses this fake ids which doesn't match any uuid reqex
    request[:path].gsub!('non-existing-disk', '<resource_id>')
    request[:path].gsub!('non-existing-vm-id', '<resource_id>')
    if request[:body]
      request[:body].gsub!(resource_id_regex, '<resource_id>')
      request[:body].gsub!(/"volume_size":\d+/, "\"volume_size\":\"<volume_size>\"")
      request[:body].gsub!(/"size":\d+/, "\"size\":\"<size>\"")
      ['user_data', 'display_description', 'device', 'password', 'fixed_ip', 'availability_zone', 'key_name', 'username', 'tenantName', 'name', 'token'].each do |key|
        scrub_random_body_value!(request, key)
      end
    end
  end
end

def unescape_double_quote(string)
  string.gsub('\"', '"') if string
end


def run
  catalog = nil
  requests = []
  STDIN.each_line do |line|

    catalog_response_regex = /excon\.response {.*?:body=>"({.*?serviceCatalog.*?})"/
    catalog_matched = catalog_response_regex.match(line)
    if catalog_matched
      catalog = JSON.parse(unescape_double_quote(catalog_matched[1]))
    end

    request_regex = /^.*excon\.request ({.*})$/
    matched = request_regex.match(line)
    if matched
      method_regex = /:method=>"([^"]*)"/
      host_regex = /:host=>"([^"]*)"/
      port_regex = /:port=>([0-9]*)/
      path_regex = /:path=>"([^"]*)"/
      query_regex = /:query=>({.*?})/
      body_regex = /:body=>"({.*?})"/

      request = {
          method: method_regex.match(matched[1])[1],
          host: host_regex.match(matched[1])[1],
          port: port_regex.match(matched[1])[1],
          path: path_regex.match(matched[1])[1],
      }
      query = query_regex.match(matched[1])
      request[:query] = query[1] if query
      body = body_regex.match(matched[1])
      request[:body] = unescape_double_quote(body[1]) if body

      requests << request
    end
  end

  if catalog
    scrub_random_values!(requests)

    requests.uniq!

    requests.each do |request|
      request[:target] = target_service(request, catalog)
    end

    catalog['access']['serviceCatalog'].each do |catalog_entry|
      puts "### All calls for API endpoint '#{catalog_entry['type']} (#{catalog_entry['name']})'"
      filtered_requests = requests.select { |request| request[:target][:type] == catalog_entry['type'] }
      if !filtered_requests.empty?
        puts '```'
        filtered_requests.sort_by! { |request| request[:path] }
        filtered_requests.each do |request|
          body = ''
          if request[:body]
            body = "body: #{unescape_double_quote(request[:body])}"
          end
          puts "#{request[:method]} #{request[:path]} #{body}"
        end
        puts '```'
        puts
      end
    end
  else
    puts 'No catalog found'
  end
end

run