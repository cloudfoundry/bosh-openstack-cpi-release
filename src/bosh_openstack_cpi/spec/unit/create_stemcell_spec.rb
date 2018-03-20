require 'spec_helper'

describe Bosh::OpenStackCloud::Cloud do
  let(:image) { double('image', id: 'i-bar') }
  let(:unique_name) { SecureRandom.uuid }

  before { @tmp_dir = Dir.mktmpdir }

  describe 'Image upload based flow' do
    let(:cloud_options) { nil }

    context 'when an environment only supports image v1' do
      before do
        @cloud = mock_glance_v1(cloud_options) do |glance|
          @glance = glance
        end
      end

      it 'creates stemcell using a stemcell file' do
        image_params = {
          name: 'stemcell-name/x.y.z',
          disk_format: 'qcow2',
          container_format: 'bare',
          location: "#{@tmp_dir}/root.img",
          is_public: false,
          properties: {
            version: 'x.y.z',
          },
        }

        expect(@glance.images).to receive(:create).with(image_params).and_return(image)
        allow(image).to receive(:reload).and_return({})
        allow(image).to receive(:status).and_return(:not_active, :active)
        expect(@cloud.openstack).to receive(:sleep).with(3)

        expect(Dir).to receive(:mktmpdir).and_yield(@tmp_dir)
        expect_any_instance_of(Bosh::OpenStackCloud::HeavyStemcellCreator).to receive(:unpack_image).with(@tmp_dir, '/tmp/foo')

        sc_id = @cloud.create_stemcell('/tmp/foo',
                                       'name' => 'stemcell-name',
                                       'version' => 'x.y.z',
                                       'container_format' => 'bare',
                                       'disk_format' => 'qcow2')

        expect(sc_id).to eq 'i-bar'
      end

      it 'sets image properties from cloud_properties' do
        image_params = {
          name: 'stemcell-name/x.y.z',
          disk_format: 'qcow2',
          container_format: 'bare',
          location: "#{@tmp_dir}/root.img",
          is_public: false,
          properties: {
            version: 'x.y.z',
            os_type: 'linux',
            os_distro: 'ubuntu',
            architecture: 'x86_64',
            auto_disk_config: 'true',
          },
        }

        expect(@glance.images).to receive(:create).with(image_params).and_return(image)

        expect(Dir).to receive(:mktmpdir).and_yield(@tmp_dir)
        expect_any_instance_of(Bosh::OpenStackCloud::HeavyStemcellCreator).to receive(:unpack_image).with(@tmp_dir, '/tmp/foo')
        expect(@cloud.openstack).to receive(:wait_resource).with(image, :active)

        sc_id = @cloud.create_stemcell('/tmp/foo',
                                       'name' => 'stemcell-name',
                                       'version' => 'x.y.z',
                                       'os_type' => 'linux',
                                       'os_distro' => 'ubuntu',
                                       'architecture' => 'x86_64',
                                       'auto_disk_config' => 'true',
                                       'foo' => 'bar',
                                       'container_format' => 'bare',
                                       'disk_format' => 'qcow2')

        expect(sc_id).to eq 'i-bar'
      end

      it 'passes through whitelisted glance properties from cloud_properties to glance when making a stemcell' do
        extra_properties = {
          'name' => 'stemcell-name',
          'version' => 'x.y.z',
          'os_type' => 'linux',
          'os_distro' => 'ubuntu',
          'architecture' => 'x86_64',
          'auto_disk_config' => 'true',
          'foo' => 'bar',
          'container_format' => 'bare',
          'disk_format' => 'qcow2',
          'hw_vif_model' => 'fake-hw_vif_model',
          'hypervisor' => 'fake-hypervisor_type', # hypervisor turns into hypervisor_type
        }

        image_params = {
          name: 'stemcell-name/x.y.z',
          disk_format: 'qcow2',
          container_format: 'bare',
          location: "#{@tmp_dir}/root.img",
          is_public: false,
          properties: {
            version: 'x.y.z',
            os_type: 'linux',
            os_distro: 'ubuntu',
            architecture: 'x86_64',
            auto_disk_config: 'true',
            hw_vif_model: 'fake-hw_vif_model',
            hypervisor_type: 'fake-hypervisor_type',
          },
        }

        expect(@glance.images).to receive(:create).with(image_params).and_return(image)

        allow(Dir).to receive(:mktmpdir).and_yield(@tmp_dir)
        expect_any_instance_of(Bosh::OpenStackCloud::HeavyStemcellCreator).to receive(:unpack_image)
        expect(@cloud.openstack).to receive(:wait_resource)

        @cloud.create_stemcell('/tmp/foo', extra_properties)
      end

      it 'should throw an error for non existent root image in stemcell archive' do
        result = Bosh::Exec::Result.new('cmd', 'output', 0)
        expect(Bosh::Exec).to receive(:sh).and_return(result)

        allow(File).to receive(:exists?).and_return(false)

        expect {
          @cloud.create_stemcell('/tmp/foo',
                                 'container_format' => 'bare',
                                 'disk_format' => 'qcow2')
        }.to raise_exception(Bosh::Clouds::CloudError, 'Root image is missing from stemcell archive')
      end

      it 'should fail if cannot extract root image' do
        result = Bosh::Exec::Result.new('cmd', 'output', 1)
        expect(Bosh::Exec).to receive(:sh).and_return(result)

        expect(Dir).to receive(:mktmpdir).and_yield(@tmp_dir)

        expect {
          @cloud.create_stemcell('/tmp/foo',
                                 'container_format' => 'ami',
                                 'disk_format' => 'ami')
        }.to raise_exception(Bosh::Clouds::CloudError,
                             'Extracting stemcell root image failed. Check task debug log for details.')
      end

      context 'stemcell_public_visibility is true' do
        let(:cloud_options) do
          cloud_options = mock_cloud_options['properties']
          cloud_options['openstack']['stemcell_public_visibility'] = true
          cloud_options
        end

        it 'sets stemcell visibility to public when required' do
          image_params = {
            name: 'stemcell-name/x.y.z',
            disk_format: 'qcow2',
            container_format: 'bare',
            location: "#{@tmp_dir}/root.img",
            is_public: true,
            properties: {
              version: 'x.y.z',
            },
          }

          expect(@glance.images).to receive(:create).with(image_params).and_return(image)

          expect(Dir).to receive(:mktmpdir).and_yield(@tmp_dir)
          expect_any_instance_of(Bosh::OpenStackCloud::HeavyStemcellCreator).to receive(:unpack_image).with(@tmp_dir, '/tmp/foo')
          expect(@cloud.openstack).to receive(:wait_resource).with(image, :active)

          sc_id = @cloud.create_stemcell('/tmp/foo',
                                         'name' => 'stemcell-name',
                                         'version' => 'x.y.z',
                                         'container_format' => 'bare',
                                         'disk_format' => 'qcow2')

          expect(sc_id).to eq 'i-bar'
        end
      end
    end

    context 'when an environment supports image v2' do
      before do
        @cloud = mock_glance_v2(cloud_options) do |glance|
          @glance = glance
        end
      end

      it 'creates an image and uploads data using a stemcell file' do
        image_params = {
          name: 'stemcell-name/x.y.z',
          disk_format: 'qcow2',
          container_format: 'bare',
          visibility: 'private',
          version: 'x.y.z',
        }

        expect(@glance.images).to receive(:create).with(image_params).and_return(image)
        allow(image).to receive(:reload).and_return({})
        allow(image).to receive(:status).and_return(:not_queued, :queued, :not_active, :active)
        expect(@cloud.openstack).to receive(:sleep).with(3).twice

        expect(Dir).to receive(:mktmpdir).and_yield(@tmp_dir)
        expect_any_instance_of(Bosh::OpenStackCloud::HeavyStemcellCreator).to receive(:unpack_image).with(@tmp_dir, '/tmp/foo')

        fake_file = double(File)

        expect(File).to receive(:open).with("#{@tmp_dir}/root.img", 'rb').and_return(fake_file)

        expect(image).to receive(:upload_data).with(fake_file)

        sc_id = @cloud.create_stemcell('/tmp/foo',
                                       'name' => 'stemcell-name',
                                       'version' => 'x.y.z',
                                       'container_format' => 'bare',
                                       'disk_format' => 'qcow2')

        expect(sc_id).to eq 'i-bar'
      end

      it 'sets custom image properties from cloud_properties' do
        image_params = {
          name: 'stemcell-name/x.y.z',
          disk_format: 'qcow2',
          container_format: 'bare',
          visibility: 'private',
          version: 'x.y.z',
          os_type: 'linux',
          os_distro: 'ubuntu',
          architecture: 'x86_64',
          auto_disk_config: 'true',
        }

        expect(@glance.images).to receive(:create).with(image_params).and_return(image)

        expect(Dir).to receive(:mktmpdir).and_yield(@tmp_dir)
        expect_any_instance_of(Bosh::OpenStackCloud::HeavyStemcellCreator).to receive(:unpack_image).with(@tmp_dir, '/tmp/foo')
        expect(@cloud.openstack).to receive(:wait_resource).with(image, :queued)

        fake_file = double(File)

        expect(File).to receive(:open).with("#{@tmp_dir}/root.img", 'rb').and_return(fake_file)

        expect(image).to receive(:upload_data).with(fake_file)

        expect(@cloud.openstack).to receive(:wait_resource).with(image, :active)

        sc_id = @cloud.create_stemcell('/tmp/foo',
                                       'name' => 'stemcell-name',
                                       'version' => 'x.y.z',
                                       'os_type' => 'linux',
                                       'os_distro' => 'ubuntu',
                                       'architecture' => 'x86_64',
                                       'auto_disk_config' => 'true',
                                       'foo' => 'bar',
                                       'container_format' => 'bare',
                                       'disk_format' => 'qcow2')

        expect(sc_id).to eq 'i-bar'
      end

      it 'passes through whitelisted glance properties from cloud_properties to glance when making a stemcell' do
        extra_properties = {
          'name' => 'stemcell-name',
          'version' => 'x.y.z',
          'os_type' => 'linux',
          'os_distro' => 'ubuntu',
          'architecture' => 'x86_64',
          'auto_disk_config' => 'true',
          'foo' => 'bar',
          'container_format' => 'bare',
          'disk_format' => 'qcow2',
          'hw_vif_model' => 'fake-hw_vif_model',
          'hypervisor' => 'fake-hypervisor_type', # hypervisor turns into hypervisor_type
        }

        image_params = {
          name: 'stemcell-name/x.y.z',
          disk_format: 'qcow2',
          container_format: 'bare',
          visibility: 'private',
          version: 'x.y.z',
          os_type: 'linux',
          os_distro: 'ubuntu',
          architecture: 'x86_64',
          auto_disk_config: 'true',
          hw_vif_model: 'fake-hw_vif_model',
          hypervisor_type: 'fake-hypervisor_type',
        }

        expect(@glance.images).to receive(:create).with(image_params).and_return(image)

        allow(Dir).to receive(:mktmpdir).and_yield(@tmp_dir)
        allow_any_instance_of(Bosh::OpenStackCloud::HeavyStemcellCreator).to receive(:unpack_image)
        allow(@cloud.openstack).to receive(:wait_resource).with(image, :queued)

        fake_file = double(File)
        expect(File).to receive(:open).with("#{@tmp_dir}/root.img", 'rb').and_return(fake_file)
        expect(image).to receive(:upload_data).with(fake_file)

        allow(@cloud.openstack).to receive(:wait_resource).with(image, :active)

        @cloud.create_stemcell('/tmp/foo', extra_properties)
      end

      it 'should throw an error for non existent root image in stemcell archive' do
        result = Bosh::Exec::Result.new('cmd', 'output', 0)
        expect(Bosh::Exec).to receive(:sh).and_return(result)

        allow(File).to receive(:exists?).and_return(false)

        expect {
          @cloud.create_stemcell('/tmp/foo',
                                 'name' => 'stemcell-name',
                                 'version' => 'x.y.z',
                                 'container_format' => 'bare',
                                 'disk_format' => 'qcow2')
        }.to raise_exception(Bosh::Clouds::CloudError, 'Root image is missing from stemcell archive')
      end

      it 'should fail if cannot extract root image' do
        result = Bosh::Exec::Result.new('cmd', 'output', 1)
        expect(Bosh::Exec).to receive(:sh).and_return(result)

        expect(Dir).to receive(:mktmpdir).and_yield(@tmp_dir)

        expect {
          @cloud.create_stemcell('/tmp/foo',
                                 'name' => 'stemcell-name',
                                 'version' => 'x.y.z',
                                 'container_format' => 'ami',
                                 'disk_format' => 'ami')
        }.to raise_exception(Bosh::Clouds::CloudError,
                             'Extracting stemcell root image failed. Check task debug log for details.')
      end

      context 'stemcell_public_visibility is true' do
        let(:cloud_options) do
          cloud_options = mock_cloud_options['properties']
          cloud_options['openstack']['stemcell_public_visibility'] = true
          cloud_options
        end

        it 'sets stemcell visibility to public when required' do
          image_params = {
            name: 'stemcell-name/x.y.z',
            disk_format: 'qcow2',
            container_format: 'bare',
            visibility: 'public',
            version: 'x.y.z',
          }

          expect(@glance.images).to receive(:create).with(image_params).and_return(image)

          expect(Dir).to receive(:mktmpdir).and_yield(@tmp_dir)
          expect_any_instance_of(Bosh::OpenStackCloud::HeavyStemcellCreator).to receive(:unpack_image).with(@tmp_dir, '/tmp/foo')
          expect(@cloud.openstack).to receive(:wait_resource).with(image, :queued)

          fake_file = double(File)
          expect(File).to receive(:open).with("#{@tmp_dir}/root.img", 'rb').and_return(fake_file)
          expect(image).to receive(:upload_data).with(fake_file)

          expect(@cloud.openstack).to receive(:wait_resource).with(image, :active)

          sc_id = @cloud.create_stemcell('/tmp/foo',
                                         'name' => 'stemcell-name',
                                         'version' => 'x.y.z',
                                         'container_format' => 'bare',
                                         'disk_format' => 'qcow2')

          expect(sc_id).to eq 'i-bar'
        end
      end
    end

    context 'given a light stemcell' do
      let(:images) { double('images', get: image) }
      let(:image) { double('image', id: 'image_id', status: 'active') }

      before(:each) do
        @cloud = mock_glance_v2(cloud_options) do |glance|
          @glance = glance
          allow(glance).to receive(:images).and_return(images)
        end
      end

      it 'returns the image id with ` light` suffix' do
        cloud_properties = {
          'image_id' => 'image_id',
        }

        stemcell_id = @cloud.create_stemcell('/tmp/foo', cloud_properties)

        expect(stemcell_id).to eq('image_id light')
      end

      it 'checks if image with id exists in OpenStack' do
        cloud_properties = {
          'image_id' => 'image_id',
        }

        @cloud.create_stemcell('/tmp/foo', cloud_properties)

        expect(images).to have_received(:get).with('image_id')
      end

      context 'when image with given id does not exist in OpenStack' do
        let(:images) { double('images', get: nil) }

        it 'raises a cloud error' do
          cloud_properties = {
            'image_id' => 'non_existing_image_id',
          }

          expect {
            @cloud.create_stemcell('/tmp/foo', cloud_properties)
          }.to raise_error(Bosh::Clouds::CloudError, 'No active image with id \'non_existing_image_id\' referenced by light stemcell found in OpenStack.')
        end
      end

      context 'when image with given id is not in state `active`' do
        let(:image) { double('image', id: 'image_id', status: 'not-active') }

        it 'raises a cloud error' do
          cloud_properties = {
            'image_id' => 'image_id',
          }

          expect {
            @cloud.create_stemcell('/tmp/foo', cloud_properties)
          }.to raise_error(Bosh::Clouds::CloudError, 'No active image with id \'image_id\' referenced by light stemcell found in OpenStack.')
        end
      end
    end
  end
end
