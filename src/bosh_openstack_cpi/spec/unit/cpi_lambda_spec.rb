require "spec_helper"

describe Bosh::OpenStackCloud::CpiLambda do
  subject { described_class.create(cpi_config, cpi_log, ssl_ca_file) }
  let(:cpi_config) {
    {
        'cloud' => {
            'properties' => {
                'openstack' => {
                    'key1' => 'value1',
                    'key2' => 'value2'
                }
            }
        }
    }
  }
  let(:ssl_ca_file) { 'feel-free-to-change' }
  let(:cpi_log) { StringIO.new }

  describe 'when creating a cloud' do
    it 'passes parts of the cpi config to openstack' do
      expect(Bosh::Clouds::Openstack).to receive(:new).with({'openstack' => cpi_config['cloud']['properties']['openstack'],
                                                             'cpi_log' => cpi_log})
      subject.call({})
    end

    context 'if invalid cpi config is given' do
      let(:cpi_config) {{'empty' => 'config'}}

      it 'raises an error' do
        expect {
          subject.call({})
        }.to raise_error /Could not find cloud properties in the configuration/
      end
    end

    context 'if using ca_certs in config' do
      let(:cpi_config) {{ 'cloud' => {'properties' => { 'openstack' => {'connection_options' => {'ca_cert' => 'xyz'}}}}}}

      it 'sets ssl_ca_file that is passed and removes ca_certs' do
        expect(Bosh::Clouds::Openstack).to receive(:new).with({'openstack' => {'connection_options' => {'ssl_ca_file' => ssl_ca_file}},
                                                               'cpi_log' => cpi_log})
        subject.call({})
      end
    end

    context 'if openstack properties are provided in the context' do
      it 'merges the openstack properties' do
        context = {
            'newkey' => 'newvalue',
            'newkey2' => 'newvalue2',
        }

        expect(Bosh::Clouds::Openstack).to receive(:new).with({'openstack' => { 'key1' => 'value1',
                                                                                'key2' => 'value2',
                                                                                'newkey' => 'newvalue',
                                                                                'newkey2' => 'newvalue2'},
                                                               'cpi_log' => cpi_log})
        subject.call(context)
      end

      it 'writes the given ca_cert to the disk and sets ssl_ca_file to its path' do
        ca_file = Tempfile.new('ca_cert')

        context = {
            'newkey' => 'newvalue',
            'connection_options' => {'ca_cert' => 'xyz'}
        }

        expect(Bosh::Clouds::Openstack).to receive(:new).with({'openstack' => { 'newkey' => 'newvalue',
                                                                                'key1' => 'value1',
                                                                                'key2' => 'value2',
                                                                                'connection_options' => {'ssl_ca_file' => ca_file.path}},
                                                               'cpi_log' => cpi_log})

        described_class.create(cpi_config, cpi_log, ssl_ca_file, ca_file.path).call(context)
        expect(File.read(ca_file.path)).to eq('xyz')
      end
    end
  end
end