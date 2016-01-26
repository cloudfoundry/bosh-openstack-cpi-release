require 'rspec'

describe 'Get API calls script' do

  before(:each) do
    allow(STDIN).to receive(:each_line)
    require_relative '../../get_api_calls'
  end

  it 'prints openstack api usage markdown' do

    allow(STDIN).to receive(:each_line) do |&block|
      File.open('spec/assets/lifecycle.log') do |input|
        input.each_line &block
      end
    end

    expect {
      run
    }.to output(File.read('spec/assets/expected_api_calls.md')).to_stdout
  end

  describe 'scrub_random_values!' do

    it 'scrubs ids from path' do
      requests = requests_with_path(
          '/v2/abcdefABCDEF01234567890123456789/resources/d8d1bb51-f28b-484f-a0e5-ec0038ad3630',
          '/v2/p-abcABC123/resources/006d370a-2d1d-47c8-a96f-e75ff2b50371'
      )

      scrub_random_values!(requests)

      expect(requests.map &to_path).to all (eq('/v2/<tenant_id>/resources/<resource_id>'))
    end

    it 'scrubs pseudo id \'non-existing-disk\' from path' do
      requests = requests_with_path(
          '/v2/abcdefABCDEF01234567890123456789/resources/non-existing-disk'
      )

      scrub_random_values!(requests)

      expect(requests.map &to_path).to all (eq('/v2/<tenant_id>/resources/<resource_id>'))
    end

    it 'scrubs pseudo id \'non-existing-vm-id\' from path' do
      requests = requests_with_path(
          '/v2/abcdefABCDEF01234567890123456789/resources/non-existing-vm-id'
      )

      scrub_random_values!(requests)

      expect(requests.map &to_path).to all (eq('/v2/<tenant_id>/resources/<resource_id>'))
    end

    it 'scrubs ids from body' do
      requests = requests_with_body '{"some_id": "d8d1bb51-f28b-484f-a0e5-ec0038ad3630"}'

      scrub_random_values!(requests)

      expect(requests.map &to_body_value('some_id')).to all (eq('<resource_id>'))
    end

    it 'scrubs \'volume_size\' values from body' do
      requests = requests_with_body '{"volume_size":10}'

      scrub_random_values!(requests)

      expect(requests.map &to_body_value('volume_size')).to all (eq('<volume_size>'))
    end

    it 'scrubs \'size\' values from body' do
      requests = requests_with_body '{"volume_size":10}'

      scrub_random_values!(requests)

      expect(requests.map &to_body_value('volume_size')).to all (eq('<volume_size>'))
    end

    ['user_data', 'display_description', 'device', 'password', 'fixed_ip', 'availability_zone', 'key_name', 'username', 'tenantName', 'name', 'token'].each do |key|
      it "scrubs '#{key}' values from body" do
        requests = requests_with_body "{\"#{key}\":\"aribitrary_value\"}"

        scrub_random_values!(requests)

        expect(requests.map &to_body_value(key)).to all (eq("<#{key}>"))
      end

    end

    def to_path
      lambda {|req| req[:path]}
    end

    def to_body_value(key)
      lambda do |req|
         JSON.parse(req[:body])[key]
      end
    end

    def requests_with_body(body)
      [{
           path: '',
           body: body
       }]
    end

    def requests_with_path(*paths)
      paths.map do |path|
        {
            path: path
        }
      end
    end

  end

end