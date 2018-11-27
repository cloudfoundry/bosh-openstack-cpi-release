require 'spec_helper'

describe Bosh::OpenStackCloud::CpiLambda do
  subject { described_class.create(cpi_config, cpi_log, ssl_ca_file, ca_cert_from_context) }
  let(:cpi_config) {
    {
      'cloud' => {
        'properties' => {
          'openstack' => {
            'key1' => 'value1',
            'key2' => 'value2',
          },
        },
      },
    }
  }
  let(:ssl_ca_file) { 'feel-free-to-change' }
  let(:cpi_log) { StringIO.new }
  let(:ca_cert_from_context) { Tempfile.new('ca_cert').path }

  describe 'when creating a cloud' do
    it 'passes parts of the cpi config to openstack' do
      expect(Bosh::Clouds::Openstack).to receive(:new).with({'openstack' => cpi_config['cloud']['properties']['openstack'],
                                                            'cpi_log' => cpi_log}, 1)
      subject.call({}, 1)
    end

    context 'if invalid cpi config is given' do
      let(:cpi_config) { { 'empty' => 'config' } }

      it 'raises an error' do
        expect {
          subject.call({}, 1)
        }.to raise_error /Could not find cloud properties in the configuration/
      end
    end

    context 'if using ca_certs in config' do
      let(:cpi_config) { { 'cloud' => { 'properties' => { 'openstack' => { 'connection_options' => { 'ca_cert' => 'xyz' } } } } } }

      it 'sets ssl_ca_file that is passed and removes ca_certs' do
        expect(Bosh::Clouds::Openstack).to receive(:new).with({'openstack' => { 'connection_options' => { 'ssl_ca_file' => ssl_ca_file } },
                                                              'cpi_log' => cpi_log}, 1)
        subject.call({}, 1)
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
                                                                               'newkey2' => 'newvalue2' },
                                                              'cpi_log' => cpi_log}, 1)
        subject.call(context, 1)
      end

      it 'writes the given ca_cert to the disk and sets ssl_ca_file to its path' do
        context = {
          'newkey' => 'newvalue',
          'connection_options' => { 'ca_cert' => 'xyz' },
        }

        expect(Bosh::Clouds::Openstack).to receive(:new).with({'openstack' => { 'newkey' => 'newvalue',
                                                                               'key1' => 'value1',
                                                                               'key2' => 'value2',
                                                                               'connection_options' => { 'ssl_ca_file' => ca_cert_from_context } },
                                                              'cpi_log' => cpi_log}, 1)

        subject.call(context, 1)
        expect(File.read(ca_cert_from_context)).to eq('xyz')
      end

      context 'when the context does not include a ca_cert' do
        it 'does not write into the file' do
          allow(Bosh::Clouds::Openstack).to receive(:new)

          subject.call({}, 1)

          expect(File.read(ca_cert_from_context)).to eq('')
        end
      end
    end
  end
end
