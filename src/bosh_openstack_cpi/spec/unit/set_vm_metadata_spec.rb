require 'spec_helper'

describe Bosh::OpenStackCloud::Cloud do
  before(:each) { allow(Bosh::OpenStackCloud::TagManager).to receive(:tag_server) }

  let(:server) { double('server', id: 'i-foobar', metadata: double('metadata')) }

  context 'with a cpi version >= v2 set' do
    before(:each) do
      @cloud = mock_cloud do |fog|
        allow(fog.compute.servers).to receive(:get).with('i-foobar').and_return(server)
        allow(fog.compute).to receive(:update_server)
      end
      allow(server.metadata).to receive(:get).and_return(double('metadatum'))
    end

    context 'for normal job' do
      context "when bosh provides NO 'name' property" do
        let(:metadata) { { 'job' => 'job', 'index' => 'index' } }

        it "logs 'compiling/x'" do
          @cloud.set_vm_metadata('i-foobar', {})
          expect(Bosh::Clouds::Config.logger).to have_received(:debug).with("Tagging VM with id 'i-foobar' with '{}'")
        end
        it "sets the vm name 'job/index'" do
          @cloud.set_vm_metadata('i-foobar', metadata)
          expect(@cloud.compute).to have_received(:update_server).with('i-foobar', 'name' => 'job/index')
        end

        it 'logs job name & index' do
          @cloud.set_vm_metadata('i-foobar', metadata)
          expect(Bosh::Clouds::Config.logger).to have_received(:debug).with("Rename VM with id 'i-foobar' to 'job/index'")
        end
      end

      context "when bosh provides a 'name' property" do
        let(:metadata) { { 'name' => 'job/id' } }

        it "sets the vm name 'job/id'" do
          @cloud.set_vm_metadata('i-foobar', metadata)
          expect(@cloud.compute).to have_received(:update_server).with('i-foobar', 'name' => 'job/id')
        end

        it 'logs instance name' do
          @cloud.set_vm_metadata('i-foobar', metadata)
          expect(Bosh::Clouds::Config.logger).to have_received(:debug).with("Rename VM with id 'i-foobar' to 'job/id'")
        end
      end
    end

    context 'for compilation vms' do
      let(:metadata) { { 'compiling' => 'x' } }

      it "sets the vm name 'compiling/x'" do
        @cloud.set_vm_metadata('i-foobar', metadata)
        expect(@cloud.compute).to have_received(:update_server).with('i-foobar', 'name' => 'compiling/x')
      end

      it "logs 'compiling/x'" do
        @cloud.set_vm_metadata('i-foobar', metadata)
        expect(Bosh::Clouds::Config.logger).to have_received(:debug).with("Rename VM with id 'i-foobar' to 'compiling/x'")
      end
    end
  end
end
