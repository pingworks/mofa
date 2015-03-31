class AttributesMap
  attr_accessor :mp
  attr_accessor :cookbook
  attr_accessor :hostlist
  attr_accessor :token
  attr_accessor :option_runlist
  attr_accessor :option_attributes

  def self.create(cookbook, hostlist, token, option_runlist = nil, option_attributes = nil)
    a = AttributesMap.new
    a.cookbook = cookbook
    a.hostlist = hostlist
    a.token = token
    a.option_runlist = option_runlist
    a.option_attributes = option_attributes
    a
  end

  def initialize
    @mp = {}
  end

  def generate
    puts 'not implemented yet'
  end

end