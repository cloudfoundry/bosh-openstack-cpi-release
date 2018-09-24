require_relative './spec_helper'

describe Bosh::OpenStackCloud::Cloud do
  include Bosh::OpenStackCloud::Helpers

  before(:all) do
    @config = IntegrationConfig.new
  end

  let(:logger) { @config.logger }
  let(:openstack) { @config.create_openstack }

  before do
    delegate = double('delegate', logger: logger, cpi_task_log: nil)
    Bosh::Clouds::Config.configure(delegate)
    allow(Bosh::Clouds::Config).to receive(:logger).and_return(logger)
  end

  describe 'Glance support' do
    let(:cpi_for_stemcell) { @config.create_cpi }

    after do
      cpi_for_stemcell.delete_stemcell(@stemcell_id) if @stemcell_id
      openstack.wait_resource(@image, :deleted, :status, true) if @image
    end

    it 'uploads and deletes a stemcell' do
      @stemcell_id, stemcell_manifest = upload_stemcell(cpi_for_stemcell, @config.stemcell_path)
      expect(@stemcell_id).to_not be_nil

      @image = openstack.image.images.get(@stemcell_id)
      expect(@image).to_not be_nil
      expect(@image.name).to eq("#{stemcell_manifest['cloud_properties']['name']}/#{stemcell_manifest['cloud_properties']['version']}")
      expect(@image.visibility).to eq('private')
      expect(@image.os_distro).to eq('ubuntu')
    end
  end
end
