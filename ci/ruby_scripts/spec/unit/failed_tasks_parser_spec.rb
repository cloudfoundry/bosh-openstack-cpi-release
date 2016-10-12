require 'rspec'
require_relative '../../failed_tasks_parser'

describe 'Failed tasks parser' do

  let(:content) {
    File.read('spec/assets/bosh_tasks_output.txt')
  }

  it 'returns a bosh task command for each error' do
    expect(errors_to_bosh_tasks_cmds(content)).to eq([
      'bosh task 23 --debug',
      'bosh task 34 --debug',
      'bosh task 37 --debug'
    ])
  end

  # context "when there is no 'Failures:'" do
  #   let(:content) { 'Something with bosh task 52 --debug'}
  #
  #   it 'returns an empty commands array' do
  #     expect(parse(content)).to eq([])
  #   end
  # end

end