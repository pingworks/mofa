class AttributesMap
  attr_accessor :mp
  attr_accessor :cookbook
  attr_accessor :hostlist
  attr_accessor :token
  attr_accessor :option_runlist
  attr_accessor :option_attributes

  def self.create(cookbook, hostlist, token, option_runlist = nil, option_attributes = nil,)
    rl = RunlistMap.new
    rl.cookbook = cookbook
    rl.hostlist = hostlist
    rl.token = token
    rl.option_runlist = option_runlist
    rl.option_attributes = option_attributes
    rl
  end

  def initialize
    @mp = {}
  end

  def generate
  end

end