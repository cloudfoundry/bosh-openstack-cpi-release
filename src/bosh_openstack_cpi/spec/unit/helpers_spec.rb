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
      it 'creates a cloud error with the message of the single error' do
        expect {
          subject.fail_on_error([])
        }.not_to raise_error
      end
    end

    context 'when error is nil' do
      it 'creates a cloud error with the message of the single error' do
        expect {
          subject.fail_on_error(nil)
        }.not_to raise_error
      end
    end

    context 'when a single error is given' do
      it 'creates a cloud error with the message of the single error' do
        expect{
          subject.fail_on_error([StandardError.new('error1')])
        }.to raise_error(Bosh::Clouds::CloudError, 'error1')
      end
    end

    context 'when multiple errors' do
      it 'creates a cloud error with joined error messages' do
        errors = [
          StandardError.new('error1'),
          StandardError.new('error2')
        ]

        expect{
          subject.fail_on_error(errors)
        }.to raise_error(Bosh::Clouds::CloudError, "Multiple Cloud Errors occurred:\nerror1\nerror2")
      end

      it 'logs all errors' do
        allow(logger).to receive(:error)
        errors = [
          StandardError.new('error1'),
          StandardError.new('error2')
        ]

        expect{
          subject.fail_on_error(errors)
        }.to raise_error(Bosh::Clouds::CloudError)

        expect(logger).to have_received(:error).with(errors[0])
        expect(logger).to have_received(:error).with(errors[1])
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
        error = subject.catch_error { }
      }.to_not raise_error

      expect(error).to eq(nil)
    end
  end
end
