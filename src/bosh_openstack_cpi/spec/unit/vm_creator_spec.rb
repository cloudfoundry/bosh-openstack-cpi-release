require 'spec_helper'

describe Bosh::OpenStackCloud::VmCreator do
  subject(:vm_creator) do
    described_class.new(
      nil,
      network_configurator,
      server,
      az_provider,
      cloud_properties,
      agent_settings,
      create_vm_params,
    )
  end

  let(:network_configurator) { instance_double(Bosh::OpenStackCloud::NetworkConfigurator, prepare: nil, cleanup: nil) }
  let(:server) { double }
  let(:az_provider) { double }
  let(:cloud_properties) { {} }
  let(:agent_settings) { double }
  let(:create_vm_params) { {} }

  describe 'perform' do
    before do
      allow(az_provider).to receive(:use_multiple_azs?).and_return(multiple_azs)
      allow(server).to receive(:create)
    end

    context 'when using availability_zone' do
      let(:multiple_azs) { false }

      before do
        allow(az_provider).to receive(:select).and_return('az1')
      end

      it 'calls create server once' do
        vm_creator.perform
        expect(server).to have_received(:create).with(anything, anything, anything, include(availability_zone: 'az1'))
      end
    end

    context 'when using availability_zones' do
      let(:multiple_azs) { true }

      before do
        allow(az_provider).to receive(:select_azs).and_return(['az1', 'az2'])
      end

      it 'calls create server with the first zone' do
        vm_creator.perform
        expect(server).to have_received(:create).with(anything, anything, anything, include(availability_zone: 'az1'))
      end

      context 'when the first create server fails' do
        it 'calls create server with the second zone and logs retrying' do
          expect(server).to receive(:create).with(anything, anything, anything, include(availability_zone: 'az1')).and_raise('create-error')
          expect(server).to receive(:create).with(anything, anything, anything, include(availability_zone: 'az2'))
          vm_creator.perform
          expect(Bosh::Clouds::Config.logger).to have_received(:warn).with("Failed to create VM in AZ 'az1' with error 'create-error', retrying in a different AZ")
        end
      end

      context 'when all create servers fails' do
        it 'raises an error and logs the number of retries' do
          expect(server).to receive(:create).and_raise('create-error').twice
          expect {
            vm_creator.perform
          }.to raise_error('create-error')
          expect(Bosh::Clouds::Config.logger).to have_received(:error).with("Failed to create VM in AZ 'az2' with error 'create-error' after 2 retries. No AZs left to retry.")
        end
      end
    end
  end
end
