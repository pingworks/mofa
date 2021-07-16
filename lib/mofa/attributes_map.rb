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
    a.option_attributes = option_attributes.nil? ? {} : JSON.parse(option_attributes)
    a
  end

  def initialize
    @mp = {}
  end

  def generate
    attr_all_roles = deep_merge(option_attributes, cookbook.mofa_yml.get_attr_for_role('all'))
    attr_all_roles_local = cookbook.mofa_yml_local.get_attr_for_role('all')
    attr_all_roles = deep_merge(attr_all_roles, attr_all_roles_local)

    hostlist.list.each do |hostname|
      # Again: the underlying rule here is -> shortname = role
      attr_host_role = cookbook.mofa_yml.get_attr_for_role(Hostlist::get_role(hostname))
      attr_host_role_local = cookbook.mofa_yml_local.get_attr_for_role(Hostlist::get_role(hostname))

      attr_host_role = deep_merge(attr_host_role, attr_host_role_local)
      attr_per_host = deep_merge(attr_all_roles, attr_host_role)

      attr_per_host = deep_parse(attr_per_host, '__SHORTNAME__', Hostlist::get_shortname(hostname))

      @mp.store(hostname, attr_per_host)
    end
  end

  def deep_parse(attr_hash, placeholder, content)
    new_attr_hash = Marshal.load(Marshal.dump(attr_hash))
    attr_hash.each do |key, value|
      if value.is_a?(Hash)
        new_attr_hash[key] = deep_parse(value, placeholder, content)
      elsif value.is_a?(Array)
        new_attr_hash[key] = []
        value.each do |value_item|
          if value_item.is_a?(Hash)
            new_attr_hash[key] = deep_parse(value, placeholder, content)
          else
            new_attr_hash[key].push(value_item.gsub(Regexp.new(Regexp.escape(placeholder)), content))
          end
        end
      else
        if value
          new_attr_hash[key] = value.gsub(Regexp.new(Regexp.escape(placeholder)), content)
        end
      end
    end
    new_attr_hash
  end

  def deep_merge(attr_hash, attr_hash_local)
    new_attr_hash = Marshal.load(Marshal.dump(attr_hash))
    attr_hash.each do |key, value|
      if attr_hash_local.key?(key)
        if value.is_a?(Hash) && attr_hash_local[key].is_a?(Hash)
          new_attr_hash[key] = deep_merge(value, attr_hash_local[key])
        else
          new_attr_hash[key] = attr_hash_local[key]
        end
      end
    end
    # and now add all attributes that are in attr_hash_local but not in attr_hash
    attr_hash_local.each do |key, value|
      unless attr_hash.key?(key)
        new_attr_hash.store(key, value)
      end
    end

    new_attr_hash
  end
end
