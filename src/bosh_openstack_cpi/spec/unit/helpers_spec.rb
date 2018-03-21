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
          subject.fail_on_error(StandardError.new('error1'))
        }.to raise_error(Bosh::Clouds::CloudError, 'error1')
      end
    end

    context 'when multiple errors' do
      it 'creates a cloud error with joined error messages' do
        expect {
          subject.fail_on_error(
            StandardError.new('error1'),
            StandardError.new('error2'),
          )
        }.to raise_error(Bosh::Clouds::CloudError, "Multiple cloud errors occurred:\nerror1\nerror2")
      end

      it 'logs all errors' do
        allow(logger).to receive(:error)
        errors = %w[error1 error2].map do |text|
          error = StandardError.new(text)
          error.set_backtrace("backtrace #{text}")
          error
        end

        expect {
          subject.fail_on_error(*errors)
        }.to raise_error(Bosh::Clouds::CloudError)

        expect(logger).to have_received(:error).with(errors[0])
        expect(logger).to have_received(:error).with(errors[0].backtrace)
        expect(logger).to have_received(:error).with(errors[1])
        expect(logger).to have_received(:error).with(errors[1].backtrace)
      end
    end
  end

  describe '.catch_error' do
    it 'catches an error and return the error object' do
      error = nil
      expected_error = StandardError.new('BAAAM!')

      expect {
        error = subject.catch_error { raise expected_error }
      }.to_not raise_error

      expect(error).to eq(expected_error)
    end

    it 'returns nil if no exception given' do
      error = nil

      expect {
        error = subject.catch_error {}
      }.to_not raise_error

      expect(error).to eq(nil)
    end

    context 'when a message prefix is given' do
      it 'prefixes the error message' do
        initial_error = StandardError.new('BAAM!')
        prefix = 'My current situation'

        error = subject.catch_error(prefix) { raise initial_error }

        expect(error.message).to eq("#{prefix}: BAAM!")
        expect(error.backtrace).to eq(initial_error.backtrace)
      end
    end
  end
end
