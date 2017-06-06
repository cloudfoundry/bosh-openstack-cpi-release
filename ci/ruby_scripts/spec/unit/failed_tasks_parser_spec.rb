require 'rspec'
require 'json'
require_relative '../../failed_tasks_parser'

describe 'Failed tasks parser' do

  let(:content) {
    JSON.parse(File.read('spec/assets/bosh_tasks_output.txt'))
  }

  it 'returns a bosh task command for tasks that are not \'done\'' do
    expect(errors_to_bosh_tasks_cmds(content)).to eq([
      'bosh-go task 241 --debug',
      'bosh-go task 240 --debug'
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