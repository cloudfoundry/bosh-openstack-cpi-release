require 'spec_helper'

describe Bosh::OpenStackCloud::VmCreator do
  subject(:vm_creator) do
    described_class.new(
      cloud,
      network_configurator,
      server,
      az_provider,
      cloud_properties,
      agent_settings,
      create_vm_params,
    )
  end

  let(:cloud) { double }
  let(:network_configurator) { instance_double(Bosh::OpenStackCloud::NetworkConfigurator, prepare: nil, cleanup: nil) }
  let(:server) { double }
  let(:multiple_azs) { false }
  let(:az_provider) do
    instance_double(
      Bosh::OpenStackCloud::AvailabilityZoneProvider,
      use_multiple_azs?: multiple_azs,
      select: nil,
    )
  end
  let(:cloud_properties) { {} }
  let(:agent_settings) { double }
  let(:create_vm_params) { {} }
  let(:manual_network) { { 'network_a' => manual_network_spec(ip: '10.0.0.1') } }
  let(:environment) { { 'test_env' => 'value' } }

  describe 'perform' do
    before do
      allow(server).to receive(:create)
    end

    context 'when vm creation fails' do
      before(:each) do
        allow(server).to receive(:create).and_raise 'BOOM!!!'
        allow(network_configurator).to receive(:prepare)
      end

      it 'cleans up network resources' do
        expect(network_configurator).to receive(:cleanup)

        expect {
          subject.perform
        }.to raise_error RuntimeError, 'BOOM!!!'
      end

      it 'ignores but warns about network resource cleanup failures' do
        allow(network_configurator).to receive(:cleanup).and_raise 'BOOM Cleanup!!!'

        expect {
          subject.perform
        }.to raise_error RuntimeError, 'BOOM!!!'
      end
    end

    context 'when using availability_zone' do
      before do
        allow(az_provider).to receive(:select).and_return('az1')
      end

      it 'calls create server once' do
        subject.perform
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
          expect(network_configurator).to receive(:prepare).once
          expect(server).to receive(:create)
            .with(anything, anything, anything, include(availability_zone: 'az1'))
            .and_raise('create-error')

          expect(server).to receive(:create).with(anything, anything, anything, include(availability_zone: 'az2'))

          vm_creator.perform

          expect(Bosh::Clouds::Config.logger).to have_received(:warn)
            .with("Failed to create VM in AZ 'az1' with error 'create-error', retrying in a different AZ")
        end
      end

      context 'when all create servers fails' do
        before do
          expect(network_configurator).to receive(:cleanup).once
          expect(network_configurator).to receive(:prepare).once

          expect(server).to receive(:create)
            .with(anything, anything, anything, include(availability_zone: 'az1'))
            .and_raise('create-error-1')
          expect(server).to receive(:create)
            .with(anything, anything, anything, include(availability_zone: 'az2'))
            .and_raise('create-error-2')
        end

        it 'raises an error and logs the number of retries' do
          expect { vm_creator.perform }.to raise_error('create-error-2')

          expect(Bosh::Clouds::Config.logger).to have_received(:error)
            .with("Failed to create VM in AZ 'az2' with error 'create-error-2' after 2 retries. No AZs left to retry.")
        end

        it 'ignores but warns about network resource cleanup failures' do
          allow(network_configurator).to receive(:cleanup).and_raise 'BOOM Cleanup!!!'
          expect(Bosh::Clouds::Config.logger).to receive(:warn)
            .with('Failed to cleanup network resources: BOOM Cleanup!!!')

          expect { subject.perform }.to raise_error('create-error-2')
        end
      end
    end
  end
end
