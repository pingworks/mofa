require 'mofa/hostlist'
require 'mofa/config'

describe Hostlist do
  before do
    Mofa::Config.load

  end
  it "should initialize" do
    hostlist = Hostlist.create("/.*/", "file://rspec/mofa/test_hostlist.json")
    hostlist != nil
  end
  it "should retrieve" do
    hostlist = Hostlist.create("/.*/", "file://rspec/mofa/test_hostlist.json")
    puts     hostlist.retrieve.count
  end

end
