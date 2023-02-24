require 'spec_helper'

describe Bosh::OpenStackCloud::Cloud do
  let(:default_connection_options) {
    { 'instrumentor' => Bosh::OpenStackCloud::ExconLoggingInstrumentor }
  }
  let(:cpi_api_version) { 2 }

  describe :update_agent_settings do
    let(:cloud_options) { mock_cloud_options }
    let(:connection_options) { nil }
    let(:merged_connection_options) { default_connection_options }

    let(:compute) { instance_double('Fog::OpenStack::Compute') }
    before { allow(Fog::OpenStack::Compute).to receive(:new).and_return(compute) }

    let(:image) { instance_double('Fog::Image') }
    before { allow(Fog::OpenStack::Image).to receive(:new).and_return(image) }

    context 'when registry is not used' do
      let(:cpi_api_version) { 2 }
      let(:cloud_options_stemcell_v2) do
        cloud_options['properties']['openstack']['vm'] = {
          'stemcell' => {
            'api_version' => 2,
          },
        }
        cloud_options
      end
      it 'does not log anything' do
        cpi = Bosh::OpenStackCloud::Cloud.new(cloud_options_stemcell_v2['properties'], cpi_api_version)
        server = double('server', id: 'id', name: 'name', metadata: double('metadata'))
        allow(server.metadata).to receive(:get).and_return(nil)
        expect(cpi.logger).to_not receive(:info)
      end
    end
  end

  describe :info do
    let(:cloud_options) { mock_cloud_options }

    it 'returns correct info' do
      cpi = Bosh::OpenStackCloud::Cloud.new(cloud_options['properties'], cpi_api_version)
      expect(cpi.info).to eq('api_version' => 2, 'stemcell_formats' => ['openstack-raw', 'openstack-qcow2', 'openstack-light'])
    end
  end

end
