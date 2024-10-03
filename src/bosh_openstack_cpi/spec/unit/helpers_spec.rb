require 'spec_helper'

describe Bosh::OpenStackCloud::Helpers do
  let(:logger) { double('logger', error: nil) }

  let(:helpers_user) do
    Class.new do
      include Bosh::OpenStackCloud::Helpers
      def initialize(logger)
        @logger = logger
      end
    end
  end

  subject {
    helpers_user.new(logger)
  }

  describe '.fail_on_error' do
    context 'when no error is given' do
      it 'does not raise an error' do
        expect {
          subject.fail_on_error
        }.not_to raise_error
      end
    end

    context 'when error is nil' do
      it 'does not raise an error' do
        expect {
          subject.fail_on_error(nil)
        }.not_to raise_error
      end
    end

    context 'when a single error is given' do
      it 'creates a cloud error with the message of the single error' do
        expect {
          subject.fail_on_error(Bosh::OpenStackCloud::Helpers::ErrorWrapper.new(StandardError.new('error1')))
        }.to raise_error(Bosh::Clouds::CloudError, 'error1')
      end
    end

    context 'when multiple errors' do
      it 'creates a cloud error with joined error messages' do
        expect {
          subject.fail_on_error(
              Bosh::OpenStackCloud::Helpers::ErrorWrapper.new(StandardError.new('error1')),
              Bosh::OpenStackCloud::Helpers::ErrorWrapper.new(StandardError.new('error2')),
          )
        }.to raise_error(Bosh::Clouds::CloudError, "Multiple cloud errors occurred:\nerror1\nerror2")
      end

      it 'logs all errors' do
        allow(logger).to receive(:error)
        error_wrappers = %w[error1 error2].map do |text|
          error = StandardError.new(text)
          error.set_backtrace("backtrace #{text}")
          Bosh::OpenStackCloud::Helpers::ErrorWrapper.new(error)
        end

        expect {
          subject.fail_on_error(*error_wrappers)
        }.to raise_error(Bosh::Clouds::CloudError)

        expect(logger).to have_received(:error).with(error_wrappers[0].error)
        expect(logger).to have_received(:error).with(error_wrappers[0].error.backtrace)
        expect(logger).to have_received(:error).with(error_wrappers[1].error)
        expect(logger).to have_received(:error).with(error_wrappers[1].error.backtrace)
      end
    end
  end

  describe '.catch_error' do
    it 'catches an error and return the error object' do
      error_wrapper = nil
      expected_error = StandardError.new('BAAAM!')

      expect {
        error_wrapper = subject.catch_error { raise expected_error }
      }.to_not raise_error

      expect(error_wrapper.error).to eq(expected_error)
    end

    it 'returns nil if no exception given' do
      error = nil

      expect {
        error = subject.catch_error {
          # intentionally empty
        }
      }.to_not raise_error

      expect(error).to eq(nil)
    end

    context 'when a message prefix is given' do
      it 'prefixes the error message' do
        initial_error = StandardError.new('BAAM!')
        prefix = 'My current situation'

        error_wrapper = subject.catch_error(prefix) { raise initial_error }

        expect(error_wrapper.message).to eq("#{prefix}: BAAM!")
        expect(error_wrapper.error.backtrace).to eq(initial_error.backtrace)
      end

      context 'when Excon::Error::Socket is raised' do
        before(:each) do
          allow(logger).to receive(:error)
        end

        it 'does return the same exception and logs prefix' do
          initial_error = Excon::Error::Socket.new
          prefix = 'Does not raise undefined method message'

          error_wrapper = subject.catch_error(prefix) { raise initial_error }

          expect(error_wrapper.error).to be(initial_error)
        end
      end
    end
  end
end
