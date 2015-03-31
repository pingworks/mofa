class RunlistMap
  attr_accessor :mp
  attr_accessor :cookbook
  attr_accessor :hostlist
  attr_accessor :token
  attr_accessor :option_runlist
  attr_accessor :default_runlist

  def self.create(cookbook, hostlist, token, option_runlist = nil)
    rl = RunlistMap.new
    rl.cookbook = cookbook
    rl.hostlist = hostlist
    rl.token = token
    rl.default_runlist = (!option_runlist.nil?) ? option_runlist : nil
    rl
  end

  def initialize
    @mp = {}
  end

  def generate
    @default_runlist ||= "recipe[#{cookbook.name}::default]"

    case cookbook.type
      when 'env'
        guess_runlists_by_hostnames
      else
        set_default_runlist_for_every_host
    end
  end

  def guess_runlists_by_hostnames
    # recipes/jkmaster.rb --> runlist[<env_cookbook_name>::jkmaster] for all hosts with shortname jkmaster
    # recipes/jkslave.rb --> runlist[<env_cookbook_name>::jkslave] for all hosts with shortname jkslave[0-9]
    # and so on
    hostlist.list.each do |hostname|
      cookbook.recipes.each do |recipe|
        recipe_regex = "^#{recipe}[0-9]*\."
        if hostname.match(recipe_regex)
          @mp.store(hostname, "recipe[#{cookbook.name}::#{recipe}]")
        end
      end
    end

  end

  def set_default_runlist_for_every_host
    hostlist.list.each do |hostname|
      @mp.store(hostname, @default_runlist)
    end
  end

end