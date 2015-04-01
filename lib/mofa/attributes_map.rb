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
    attr_all_roles = cookbook.mofa_yml.get_attr_for_role('all')
    attr_all_roles_local = cookbook.mofa_yml_local.get_attr_for_role('all')
    attr_all_roles.merge!(attr_all_roles_local)
    hostlist.list.each do |hostname|
      # Again: the underlying rule here is -> shortname = role
      attr_host_role = cookbook.mofa_yml.get_attr_for_role(Hostlist::get_role(hostname))
      attr_host_role_local = cookbook.mofa_yml_local.get_attr_for_role(Hostlist::get_role(hostname))
      attr_host_role.merge!(attr_host_role_local)
      attr_per_host = attr_all_roles.merge(attr_host_role)
      @mp.store(hostname, attr_per_host)
    end
  end

end