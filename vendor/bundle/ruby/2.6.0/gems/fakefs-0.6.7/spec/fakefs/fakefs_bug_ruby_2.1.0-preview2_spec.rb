require 'find'
require 'fakefs/spec_helpers'

RSpec.configure do |c|
  c.mock_with(:rspec)
  c.include(FakeFS::SpecHelpers, fakefs: true)
  c.disable_monkey_patching!
end

if RUBY_VERSION >= '2.1'
  RSpec.describe 'Find.find', fakefs: true do
    it 'does not give an ArgumentError' do
      FileUtils.mkdir_p('/tmp/foo')
      found = Find.find('/tmp').to_a
      expect(found).to eq(%w(/tmp /tmp/foo))
    end
  end
end
