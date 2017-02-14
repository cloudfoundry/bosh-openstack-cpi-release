require 'rspec'
require_relative '../../api_calls'

describe 'Get API calls script' do

  before(:each) do
    allow(STDIN).to receive(:each_line)
  end

  describe '#update_catalog' do
    let(:catalog) {
      {
        v2: {},
        v3: {}
      }
    }

    context 'with Keystone API V2' do
      let(:line) { 'D, [2015-12-08T12:46:56.914657 #18654] DEBUG -- : excon.response {:body=>"{"access":{"token":{"issued_at":"2015-12-08T12:46:56.832969","expires":"2015-12-09T12:46:56Z","id":"f71ab62d41644108a018310931865d73","tenant":{"description":"","enabled":true,"id":"ab7c42f3cb064b13999d63da9ff9bdd0","name":"the-name"}},"serviceCatalog":[{"endpoints":[{"adminURL":"https://my.openstack.domain.com:8778/v1/ab7c42f3cb064b13999d63da9ff9bdd0","region":"RegionOne","internalURL":"https://my.openstack.domain.com:8778/v1/ab7c42f3cb064b13999d63da9ff9bdd0","id":"1238b8d065b04ba582ab1e6ed41cf865","publicURL":"https://my.openstack.domain.com:8778/v1/ab7c42f3cb064b13999d63da9ff9bdd0"}],"endpoints_links":[],"type":"volume","name":"cinder"}, {"endpoints":[{"adminURL":"https://my.openstack.domain.com:8778/v2/ab7c42f3cb064b13999d63da9ff9bdd0","region":"RegionOne","internalURL":"https://my.openstack.domain.com:8778/v2/ab7c42f3cb064b13999d63da9ff9bdd0","id":"1238b8d065b04ba582ab1e6ed41cf865","publicURL":"https://my.openstack.domain.com:8778/v2/ab7c42f3cb064b13999d63da9ff9bdd0"}],"endpoints_links":[],"type":"volumev2","name":"cinder"}, {\"endpoints\": [{\"adminURL\": \"https://my.openstack.domain.com:9797\", \"region\": \"RegionOne\", \"internalURL\": \"https://my.openstack.domain.com:9797\", \"id\": \"54410834aedb46ad95a351a0dbccd648\", \"publicURL\": \"https://my.openstack.domain.com:9797\"}], \"endpoints_links\": [], \"type\": \"network\", \"name\": \"neutron\"},{"endpoints":[{"adminURL":"http://my.openstack.domain.com:9292","region":"RegionOne","internalURL":"http://my.openstack.domain.com:9292","id":"123f7ccb37214522b7ffc49867600b40","publicURL":"http://my.openstack.domain.com:9292"}],"endpoints_links":[],"type":"image","name":"glance"}],"user":{"username":"my-bosh-user","roles_links":[],"id":"123927eb6b11464b8161c1fc2e80132d","roles":[{"name":"_member_"},{"name":"service"}],"name":"my-bosh-user"},"metadata":{"is_admin":0,"roles":["1232ff9ee4384b1894a90878d3e92bab","1233f2fbbf11434eb957a031e7af52d6"]}}}", :headers=>{"Vary"=>"X-Auth-Token", "Content-Type"=>"application/json", "Date"=>"Tue, 08 Dec 2015 12:46:56 GMT", "Connection"=>"close"}, :status=>200, :status_line=>"HTTP/1.1 200 OK\r\n", :reason_phrase=>"OK", :remote_ip=>"173.247.104.14", :local_port=>56637, :local_address=>"10.254.1.58"}' }
      it 'returns a catalog' do
        update_catalog(catalog, line)

        expect(catalog[:v2]).not_to be_empty
        expect(catalog[:v3]).to be_empty
      end
    end

    context 'with Keystone API V3' do
      let(:line) { 'D, [2017-01-24T19:05:26.819094 #146] DEBUG -- : excon.response {:body=>"{"token":{"methods":["password"],"roles":[{"id":"9fe2ff9ee4384b1894a90878d3e92bab","name":"_member_"}],"expires_at":"2017-01-25T19:05:26.783472Z","project":{"domain":{"id":"default","name":"Default"},"id":"aa8c1b2160b8497483539cfe9cb89ef5","name":"my-bosh-user"},"catalog":[{"endpoints":[{"region_id":"RegionOne","url":"https://my.openstack.domain.com:8776/v2/aa8c1b2160b8497483539cfe9cb89ef5","region":"RegionOne","interface":"public","id":"438cc291180b449ab810f2c967980d94"},{"region_id":"RegionOne","url":"https://my.openstack.domain.com:8776/v2/aa8c1b2160b8497483539cfe9cb89ef5","region":"RegionOne","interface":"internal","id":"7f47a2679cc6409ba2cba2f1537488e5"},{"region_id":"RegionOne","url":"https://my.openstack.domain.com:8776/v2/aa8c1b2160b8497483539cfe9cb89ef5","region":"RegionOne","interface":"admin","id":"9e9a1867773e4ea593c57e4acfefa1c4"}],"type":"volumev2","id":"25e98afbde414cdc9f9ce7d3e7459e2b","name":"cinderv2"},{"endpoints":[{"region_id":"RegionOne","url":"https://my.openstack.domain.com:9696","region":"RegionOne","interface":"public","id":"5883cd766e38431cbe7bde2b3233ea0d"},{"region_id":"RegionOne","url":"https://my.openstack.domain.com:9696","region":"RegionOne","interface":"internal","id":"be6a723c471a41bdb21de1689ab26cab"},{"region_id":"RegionOne","url":"https://my.openstack.domain.com:9696","region":"RegionOne","interface":"admin","id":"f9bfd0e6d8144e058003c393926508f4"}],"type":"network","id":"27ab58ab01214baba7efb62e8cab1b06","name":"neutron"},{"endpoints":[{"region_id":"RegionOne","url":"https://my.openstack.domain.com:9292","region":"RegionOne","interface":"admin","id":"8b488ea20be94c21821c9e7904bafda2"},{"region_id":"RegionOne","url":"https://my.openstack.domain.com:9292","region":"RegionOne","interface":"public","id":"a720e1460a1c4eadb71cd321be342937"},{"region_id":"RegionOne","url":"https://my.openstack.domain.com:9292","region":"RegionOne","interface":"internal","id":"d4cd98b2fa0b473db450703df11273ab"}],"type":"image","id":"28fb19dc2c1d4a36b09eab9545ba7edf","name":"glance"},{"endpoints":[{"region_id":"RegionOne","url":"https://my.openstack.domain.com:8776/v1/aa8c1b2160b8497483539cfe9cb89ef5","region":"RegionOne","interface":"public","id":"374a949e21b4460d8d4289f529444e79"},{"region_id":"RegionOne","url":"https://my.openstack.domain.com:8776/v1/aa8c1b2160b8497483539cfe9cb89ef5","region":"RegionOne","interface":"internal","id":"3ce1717763554fb7accb10e8beeef1fb"},{"region_id":"RegionOne","url":"https://my.openstack.domain.com:8776/v1/aa8c1b2160b8497483539cfe9cb89ef5","region":"RegionOne","interface":"admin","id":"f04d1b631484459487afdf5aa6c90b91"}],"type":"volume","id":"2d931a278eac4498932f0374e1c096d0","name":"cinder"},{"endpoints":[{"region_id":"RegionOne","url":"https://my.openstack.domain.com:8004/v1/aa8c1b2160b8497483539cfe9cb89ef5","region":"RegionOne","interface":"admin","id":"e69534d65a644e72b78cdcc56f479a70"},{"region_id":"RegionOne","url":"https://my.openstack.domain.com:8004/v1/aa8c1b2160b8497483539cfe9cb89ef5","region":"RegionOne","interface":"internal","id":"e910fa08c27e4fd2a122affefd445fd2"},{"region_id":"RegionOne","url":"https://my.openstack.domain.com:8004/v1/aa8c1b2160b8497483539cfe9cb89ef5","region":"RegionOne","interface":"public","id":"eefca2577b924a83b1ce97e88a67dc7b"}],"type":"orchestration","id":"47e055e981ea4d70a53342e9752d65a0","name":"heat"},{"endpoints":[{"region_id":"RegionOne","url":"https://my.openstack.domain.com:8000/v1","region":"RegionOne","interface":"public","id":"88c48ce3c8ec4ae7a65b75e4f0aef6b8"},{"region_id":"RegionOne","url":"https://my.openstack.domain.com:8000/v1","region":"RegionOne","interface":"internal","id":"ba4f5e696ea44976ab3f554beb6090e9"},{"region_id":"RegionOne","url":"https://my.openstack.domain.com:8000/v1","region":"RegionOne","interface":"admin","id":"c00bd34c63c64b3b9d41891743c09517"}],"type":"cloudformation","id":"6b805f97a5e34b9e89452df9ba870ce1","name":"heat-cfn"},{"endpoints":[{"region_id":"RegionOne","url":"https://my.openstack.domain.com:35357/v3","region":"RegionOne","interface":"admin","id":"5459953d0ee841d294259a0613d3da43"},{"region_id":"RegionOne","url":"https://my.openstack.domain.com:5000/v3","region":"RegionOne","interface":"public","id":"9e21dd10a390424481a38bb5ceab5e76"},{"region_id":"RegionOne","url":"https://my.openstack.domain.com:5000/v3","region":"RegionOne","interface":"internal","id":"b93dd2f0f8094555b717d0ead2daf14d"}],"type":"identityv3","id":"bedc220c02984a7ea8eaa45543a384eb","name":"keystonev3"},{"endpoints":[{"region_id":"RegionOne","url":"https://my.openstack.domain.com:8774/v2/aa8c1b2160b8497483539cfe9cb89ef5","region":"RegionOne","interface":"internal","id":"00ed30b21f6a4d46ae5e5c758b150711"},{"region_id":"RegionOne","url":"https://my.openstack.domain.com:8774/v2/aa8c1b2160b8497483539cfe9cb89ef5","region":"RegionOne","interface":"admin","id":"231e19aa3c5a47f78f4a8e53fe4193bf"},{"region_id":"RegionOne","url":"https://my.openstack.domain.com:8774/v2/aa8c1b2160b8497483539cfe9cb89ef5","region":"RegionOne","interface":"public","id":"99d31cb6f898438881a313b8c09020a9"}],"type":"compute","id":"d1b4eaa3e18443eb8807390b7dbf2c57","name":"nova"},{"endpoints":[{"region_id":"RegionOne","url":"https://my.openstack.domain.com:35357/v2.0","region":"RegionOne","interface":"admin","id":"476c88a4c2314dbd94be8d4ab90eac77"},{"region_id":"RegionOne","url":"https://my.openstack.domain.com:5000/v2.0","region":"RegionOne","interface":"public","id":"ebb971e57f81422191753004aa9a9225"},{"region_id":"RegionOne","url":"https://my.openstack.domain.com:5000/v2.0","region":"RegionOne","interface":"internal","id":"f9fe3af6a361412795d7db69ddda5ff1"}],"type":"identity","id":"fe93547df5e0486c82883edeea744962","name":"keystone"}],"user":{"domain":{"id":"default","name":"Default"},"id":"68c290be53b1476280f2dfefdd0a8aed","name":"my-project"},"audit_ids":["rJQ_eCbtQ8ax9mtrVKA5xQ"],"issued_at":"2017-01-24T19:05:26.783515Z"}}", :headers=>{"X-Subject-Token"=>"1a12fa7e501e481094b84ee983593ec9", "Vary"=>"X-Auth-Token", "Content-Type"=>"application/json", "Content-Length"=>"6928", "x-openstack-request-id"=>"req-8ce7cfac-de18-45f9-85c1-75780c0727d0", "Connection"=>"close", "X-Auth-Token"=>"<redacted>"}, :status=>201, :remote_ip=>"my-ip", :cookies=>[], :host=>"my.openstack.domain.com", :path=>"/v3/auth/tokens", :port=>5000, :status_line=>"HTTP/1.1 201 Created\r\n", :reason_phrase=>"Created", :local_port=>51972, :local_address=>"10.254.1.106"}' }
      it 'returns a catalog' do
        update_catalog(catalog, line)

        expect(catalog[:v3]).not_to be_empty
        expect(catalog[:v2]).to be_empty
      end
    end
  end

  describe '#run' do
    context 'when no response contains a catalog' do
      it 'raises an error' do

        expect {
          run
        }.to raise_error('No catalog found')
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
              File.open('spec/assets/catalog_v2.log') do |catalog_v3|
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
      requests = requests_with_body '{"volume_size":10}'

      scrub_random_values!(requests)

      expect(requests.map &to_body_value('volume_size')).to all (eq('<volume_size>'))
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

    ['user_data', 'display_description', 'device', 'password', 'fixed_ip', 'availability_zone', 'key_name', 'username', 'tenantName', 'name', 'token', 'ip_address', 'device_id', 'floating_ip_address', 'network_id', 'description'].each do |key|
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
    end

    def to_path
      lambda {|req| req[:path]}
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