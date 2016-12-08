require 'spec_helper'

describe Bosh::OpenStackCloud::Redactor do

  subject { Bosh::OpenStackCloud::Redactor }
  let(:hash) {
    {
        'a' => {
            'b' => {
                'property' => 'secret'
            }
        }
    }
  }

  let(:hash_with_symbols) {
    {
        :a => {
            :b => {
                :property => 'secret'
            }
        }
    }
  }

  describe '.redact' do
    it 'redacts a given paths from the given hash' do
      redacted_hash = subject.redact(hash, 'a.b.property')

      expect(redacted_hash).to be(hash)
      expect(redacted_hash['a']['b']['property']).to eq('<redacted>')
    end

    context 'when given property does not exist' do
      let(:hash) { {} }
      it 'does not add the redacted string' do

        redacted_hash = subject.redact(hash, 'property')

        expect(redacted_hash['property']).to be_nil
      end
    end

    context 'given hash with symbols' do

      it 'does not redact a given path from the given hash' do
        redacted_hash = subject.redact(hash_with_symbols, 'a.b.property')

        expect(redacted_hash).to be(hash_with_symbols)
        expect(redacted_hash[:a][:b][:property]).to eq('secret')
      end
    end
  end

  describe '.clone_and_redact' do
    it 'clones and redacts a given paths from the given hash' do
      redacted_hash = subject.clone_and_redact(hash, 'a.b.property')

      expect(redacted_hash).to_not be(hash)
      expect(redacted_hash['a']['b']['property']).to eq('<redacted>')
      expect(hash['a']['b']['property']).to eq('secret')
    end

    context 'given hash with symbols' do
      it 'clones and redacts a given paths from the given hash' do
        redacted_hash = subject.clone_and_redact(hash_with_symbols, 'a.b.property')

        expect(redacted_hash).to_not be(hash_with_symbols)
        expect(redacted_hash['a']['b']['property']).to eq('<redacted>')
        expect(hash_with_symbols[:a][:b][:property]).to eq('secret')
      end
    end
  end
end
