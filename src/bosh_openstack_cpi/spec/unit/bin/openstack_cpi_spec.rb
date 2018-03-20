require 'spec_helper'
require 'tempfile'
require 'English'

describe 'the openstack_cpi executable' do
  describe '#set_vm_metadata' do
    it 'will not evaluate anything that causes an exception and will return the proper message to stdout' do
      config_file = create_config_file('0.0.0.0:5000/v2.0')
      command_file = create_cpi_command_file('set_vm_metadata', [1, {}])

      stdoutput = execute_cpi_command(command_file, config_file)
      status = $CHILD_STATUS.exitstatus

      expect(status).to eq(0)
      result = JSON.parse(stdoutput)

      expect(result.keys).to eq(%w[result error log])

      expect(result['result']).to be_nil

      expect(result['error']).to eq(
        'type' => 'Unknown',
        'message' => 'bad URI(is not URI?): 0.0.0.0:5000/v2.0/tokens',
        'ok_to_retry' => false,
      )

      expect(result['log']).to include('backtrace')
    end

    it 'will fail if registry.endpoint is not provided' do
      config_file = create_config_file('http://0.0.0.0:5000/v2.0', nil)
      command_file = create_cpi_command_file('set_vm_metadata', [1, {}])

      stdoutput = execute_cpi_command(command_file, config_file)

      result = JSON.parse(stdoutput)

      expect(result['result']).to be_nil
      expect(result['error']['type']).to eq('InvalidCall')
      expect(result['error']['message']).to match(/#<Membrane::SchemaValidationError: { registry => { endpoint => Missing key } }/)
      expect(result['error']['ok_to_retry']).to eq(false)
    end

    it 'will return an appropriate error message when passed an invalid config file' do
      config_file = Tempfile.new('cloud_properties.yml')
      File.open(config_file, 'w') do |file|
        file.write({}.to_yaml)
      end

      command_file = create_cpi_command_file('set_vm_metadata', [1, {}])

      stdoutput = execute_cpi_command(command_file, config_file)
      status = $CHILD_STATUS.exitstatus

      expect(status).to eq(0)
      result = JSON.parse(stdoutput)

      expect(result.keys).to eq(%w[result error log])

      expect(result['result']).to be_nil

      expect(result['error']).to eq(
        'type' => 'Unknown',
        'message' => 'Could not find cloud properties in the configuration',
        'ok_to_retry' => false,
      )

      expect(result['log']).to include('backtrace')
    end
  end

  describe '#calculate_vm_cloud_properties' do
    it 'raises an error if calculate_vm_cloud_properties fields are missing' do
      config_file = create_config_file('0.0.0.0:5000/v2.0')
      command_file = create_cpi_command_file('calculate_vm_cloud_properties', [{}])

      stdoutput = execute_cpi_command(command_file, config_file)
      status = $CHILD_STATUS.exitstatus

      expect(status).to eq(0)
      result = JSON.parse(stdoutput)

      expect(result.keys).to eq(%w[result error log])

      expect(result['result']).to be_nil

      expect(result['error']).to eq(
        'type' => 'Unknown',
        'message' => "Missing VM cloud properties: 'cpu', 'ram', 'ephemeral_disk_size'",
        'ok_to_retry' => false,
      )

      expect(result['log']).to include('backtrace')
    end
  end
end

def create_config_file(auth_url = 'http://0.0.0.0:5000/v2.0', registry_endpoint = '0.0.0.0:5000')
  config_file = Tempfile.new('cloud_properties.yml')
  File.open(config_file, 'w') do |file|
    file.write(
      {
        'cloud' => {
          'properties' => {
            'openstack' => {
              'auth_url' => auth_url,
              'username' => 'openstack-user',
              'api_key' => 'openstack-password',
              'tenant' => 'dev',
              'region' => 'west-coast',
              'endpoint_type' => 'publicURL',
              'state_timeout' => 300,
              'boot_from_volume' => false,
              'stemcell_public_visibility' => false,
              'connection_options' => {},
              'default_key_name' => nil,
              'default_security_groups' => nil,
              'wait_resource_poll_interval' => 5,
              'config_drive' => 'disk',
            },
            'registry' => {
              'endpoint' => registry_endpoint,
              'user' => 'registry-user',
              'password' => 'registry-password',
            },
          },
        },
      }.to_yaml,
    )
  end
  config_file
end

def create_cpi_command_file(method_name, method_args)
  command_file = Tempfile.new('command.json')
  File.open(command_file, 'w') do |file|
    file.write({ 'method' => method_name, 'arguments' => method_args, 'context' => { 'director_uuid' => 'abc123' } }.to_json)
  end
  command_file
end

def execute_cpi_command(command_file, config_file)
  `bin/openstack_cpi #{config_file.path} < #{command_file.path} 2> /dev/null`
end
