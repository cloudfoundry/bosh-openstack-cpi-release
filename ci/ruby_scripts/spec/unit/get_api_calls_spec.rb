require 'rspec'
require_relative '../../api_calls'

describe 'Get API calls script' do

  before(:each) do
    allow(STDIN).to receive(:each_line)
  end

  describe '#update_catalog' do

    context 'with Keystone API V2' do
      it 'returns a catalog' do
        File.open('spec/assets/catalog_v2.log').each do |catalog_v2_line|
          expect(update_catalog_endpoints(catalog_v2_line)[0]["endpoints"]).not_to be_empty
        end
      end
    end

    context 'with Keystone API V3' do
      it 'returns a catalog' do
        File.open('spec/assets/catalog_v3.log').each do |catalog_v3_line|
          expect(update_catalog_endpoints(catalog_v3_line)[0]["endpoints"]).not_to be_empty
        end
      end
    end
  end

  describe '#run' do
    context 'when no response contains a catalog' do
      it 'raises an error' do

        expect {
          run
        }.to raise_error('No catalog with endpoints found')
      end
    end

    context 'with Keystone API V2' do
      it 'prints openstack api usage markdown' do
        allow(STDIN).to receive(:each_line) do |&block|
          File.open('spec/assets/lifecycle.log') do |lifecycle|
            File.open('spec/assets/catalog_v2.log') do |catalog|
              lifecycle.each_line &block
              catalog.each_line &block
            end
          end
        end

        expect {
          run
        }.to output(File.read('spec/assets/expected_api_calls.md')).to_stdout
      end
    end

    context 'with Keystone API V3' do
      it 'prints openstack api usage markdown' do
        allow(STDIN).to receive(:each_line) do |&block|
          File.open('spec/assets/lifecycle.log') do |lifecycle|
            File.open('spec/assets/catalog_v3.log') do |catalog|
              lifecycle.each_line &block
              catalog.each_line &block
            end
          end
        end

        expect {
          run
        }.to output(File.read('spec/assets/expected_api_calls.md')).to_stdout
      end
    end

    context 'with Keystone API V2 and V3' do
      it 'prefers the V3 over V2' do
        allow(STDIN).to receive(:each_line) do |&block|
          File.open('spec/assets/lifecycle.log') do |lifecycle|
            File.open('spec/assets/catalog_v2.log') do |catalog_v2|
              File.open('spec/assets/catalog_v3.log') do |catalog_v3|
                lifecycle.each_line &block
                catalog_v2.each_line &block
                catalog_v3.each_line &block
              end
            end
          end
        end

        expect {
          run
        }.to output(File.read('spec/assets/expected_api_calls.md')).to_stdout
      end
    end
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
      requests = requests_with_body '{"size":10}'

      scrub_random_values!(requests)

      expect(requests.map &to_body_value('size')).to all (eq('<size>'))
    end

    it 'scrubs \'new_size\' values from body' do
      requests = requests_with_body '{"new_size":10}'

      scrub_random_values!(requests)

      expect(requests.map &to_body_value('new_size')).to all (eq('<new_size>'))
    end

    it 'scrubs \'description\' values from body' do
      requests = requests_with_body '{"description":"deployment/some_deployment_spec/0"}'

      scrub_random_values!(requests)

      expect(requests.map &to_body_value('description')).to all (eq('<description>'))
    end

    it 'scrubs ip values from request' do
      requests = requests_with_query 'floating_ip_address=10.0.0.1'

      scrub_random_values!(requests)

      expect(requests.map { |request| request[:query] }).to all (eq('floating_ip_address=<floating_ip_address>'))
    end

    ['user_data', 'display_description', 'device', 'password', 'fixed_ip', 'availability_zone', 'key_name', 'username', 'tenantName', 'name', 'token', 'ip_address', 'device_id', 'floating_ip_address', 'network_id', 'description', 'metadata'].each do |key|
      it "scrubs '#{key}' values from body" do
        requests = requests_with_body "{\"#{key}\":\"aribitrary_value\"}"

        scrub_random_values!(requests)

        expect(requests.map &to_body_value(key)).to all (eq("<#{key}>"))
      end

      it "scrubs '#{key}' values from query" do
        requests = requests_with_query "#{key}=aribitrary_value"

        scrub_random_values!(requests)

        expect(requests.map { |request| request[:query] }).to all (eq("#{key}=<#{key}>"))
      end

      it "scrubs '#{key}' one level deep hash values from body" do
        requests = requests_with_body "{\"#{key}\":\{\"key\":\"value\"}}"

        scrub_random_values!(requests)

        expect(requests.map &to_json).to (eq([{"#{key}" => "<#{key}>"}]))

        requests_nested = requests_with_body "{\"#{key}\":\{\"nested\":{\"somekey\":\"value\"}}}"

        scrub_random_values!(requests_nested)

        expect(requests_nested.map &to_json).to (eq([{"#{key}" => { 'nested' => { 'somekey' => 'value'}}}]))
      end
    end

    def to_path
      lambda {|req| req[:path]}
    end

    def to_json
      lambda do |req|
        JSON.parse(req[:body])
      end
    end

    def to_body_value(key)
      lambda do |req|
         JSON.parse(req[:body])[key]
      end
    end

    def requests_with_query(query)
      [{
           path: '',
           query: query
       }]
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

  describe '#target_service' do
    context 'when keystone v2' do
      let(:endpoints) do
        [{
          'endpoints' => [{
            'publicURL' => 'http://sample-host.org:8080'
          }],
          'type' => 'servicebambule',
          'name' => 'bambule'
        }, {
          'endpoints' => [{
            'publicURL' => 'http://sample-host.org:9090'
          }],
          'type' => 'servicerambuno',
          'name' => 'rambuno'
        }]
      end

      it 'identifies service targeted' do
        request = {
          host: 'sample-host.org',
          port: 8080,
          path: 'v2/blablub'
        }

        expect(target_service(request, endpoints)).to eq({
          type: 'servicebambule',
          name: 'bambule'
        })
      end

      context 'with versioned services' do
        let(:request) do
          {
            host: 'sample-host.org',
            port: 8080,
            path: '/v2/path'
          }
        end

        context 'and path only with version segment' do
          let(:endpoints) do
            [{
              'endpoints' => [{
                'publicURL' => 'http://sample-host.org:8080/v1'
              }],
              'type' => 'servicebambule',
              'name' => 'bambule'
            }, {
              'endpoints' => [{
                'publicURL' => 'http://sample-host.org:8080/v2.0'
              }],
              'type' => 'servicebambulev2',
              'name' => 'bambule'
            }]
          end

          it 'can distinguish different service versions' do
            expect(target_service(request, endpoints)).to eq({
              type: 'servicebambulev2',
              name: 'bambule'
            })
          end
        end

        context 'and path with version and project id segment' do
          let(:endpoints) do
            [{
              'endpoints' => [{
                'publicURL' => 'http://sample-host.org:8080/v1/project-id'
              }],
              'type' => 'servicebambule',
              'name' => 'bambule'
            }, {
              'endpoints' => [{
                'publicURL' => 'http://sample-host.org:8080/v2.0/project-id'
              }],
              'type' => 'servicebambulev2',
              'name' => 'bambule'
            }]
          end

          it 'can distinguish different service versions' do
            expect(target_service(request, endpoints)).to eq({
              type: 'servicebambulev2',
              name: 'bambule'
            })
          end
        end
      end
    end

    context 'when keystone v3' do
      let(:endpoints) do
        [{
          'endpoints' => [{
            'url' => 'http://sample-host.org:8080/v1',
            'interface' => 'public'
          }, {
            'url' => 'http://sample-host.org:8080/v1',
            'interface' => 'public'
          }],
          'type' => 'servicebambule',
          'name' => 'bambule'
        }, {
          'endpoints' => [{
            'url' => 'http://sample-host.org:8080',
            'interface' => 'public'
          }, {
            'url' => 'http://sample-host.org:8080',
            'interface' => 'public'
          }],
          'type' => 'servicerambuno',
          'name' => 'rambuno'
        }]
      end

      it 'identifies service targeted' do
        request = {
          host: 'sample-host.org',
          port: 8080,
          path: 'v2/blablub'
        }

        expect(target_service(request, endpoints)).to eq({
          type: 'servicebambule',
          name: 'bambule'
        })
      end

      context 'with versioned services' do
        let(:request) do
          {
            host: 'sample-host.org',
            port: 8080,
            path: '/v2/path'
          }
        end
        context 'and path only with version segment' do
          let(:endpoints) do
            [{
              'endpoints' => [{
                'url' => 'http://sample-host.org:8080/v1',
                'interface' => 'public'
              }, {
                'url' => 'http://sample-host.org:8080/v1',
                'interface' => 'public'
              }],
              'type' => 'servicebambule',
              'name' => 'bambule'
            }, {
              'endpoints' => [{
                'url' => 'http://sample-host.org:8080/v2.0',
                'interface' => 'public'
              }, {
                'url' => 'http://sample-host.org:8080/v2.0',
                'interface' => 'public'
              }],
              'type' => 'servicebambulev2',
              'name' => 'bambule'
            }]
          end

          it 'can distinguish different service versions' do
            expect(target_service(request, endpoints)).to eq({
              type: 'servicebambulev2',
              name: 'bambule'
            })
          end
        end

        context 'and path with version and project id segment' do
          let(:endpoints) do
            [{
              'endpoints' => [{
                'url' => 'http://sample-host.org:8080/v1/project-id',
                'interface' => 'public'
              }, {
                'url' => 'http://sample-host.org:8080/v1/project-id',
                'interface' => 'public'
              }],
              'type' => 'servicebambule',
              'name' => 'bambule'
            }, {
              'endpoints' => [{
                'url' => 'http://sample-host.org:8080/v2.0/project-id',
                'interface' => 'public'
              }, {
                'url' => 'http://sample-host.org:8080/v2.0/project-id',
                'interface' => 'public'
              }],
              'type' => 'servicebambulev2',
              'name' => 'bambule'
            }]
          end

          it 'can distinguish different service versions' do
            expect(target_service(request, endpoints)).to eq({
              type: 'servicebambulev2',
              name: 'bambule'
            })
          end
        end
      end
    end
  end
end