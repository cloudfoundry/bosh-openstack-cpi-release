require "spec_helper"

describe Bosh::OpenStackCloud::CpiLambda do
  subject { described_class.create(cpi_config, ssl_ca_file, cpi_log) }
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
        expect(Bosh::Clouds::Openstack).to receive(:new).with({'openstack' =>
                                                                   {"connection_options" => {"ssl_ca_file" => ssl_ca_file}},
                                                               'cpi_log' => cpi_log})
        subject.call({})
      end
    end

    context 'if cpi_properties are provided in the context' do
      it 'overwrites the openstack properties' do
        context = {
            'cpi_properties' => {
                'newkey' => 'newvalue',
                'newkey2' => 'newvalue2',
            }
        }

        expect(Bosh::Clouds::Openstack).to receive(:new).with({'openstack' => context['cpi_properties'],
                                                               'cpi_log' => cpi_log})
        subject.call(context)
      end
    end
  end
end