require 'rest-client'
require 'net/ping'

class Hostlist
  attr_accessor :list
  attr_accessor :filter
  attr_accessor :service_host
  attr_accessor :service_url
  attr_accessor :filter
  attr_accessor :api_key

  def self.create(filter = nil)
    hl = Hostlist.new
    filter ||= Mofa::Config.config['service_hostlist_default_filter']
    hl.filter = filter
    hl.service_host = Mofa::Config.config['service_hostlist_url'].gsub(/^http:\/\//, '').gsub(/\/.*$/, '').gsub(/:.*$/, '')
    hl.service_url = Mofa::Config.config['service_hostlist_url']
    hl.api_key = Mofa::Config.config['service_hostlist_api_key']
    hl
  end

  def retrieve
    fail "Hostlist Service not reachable! (cannot ping #{service_host})" unless up?
    response = RestClient.get(@service_url, { :params => {:key => api_key}})
    hosts_list_json = JSON.parse response.body
    @list = hosts_list_json['data'].collect { |i| i['cname'] }

    apply_filter
    sort_by_domainname
  end


  def up?
    p = Net::Ping::TCP.new(@service_host, 'http')
    p.ping?
  end

  def apply_filter
    # building matcher
    regex = @filter.gsub(/\*/, '__ASTERISK__')
    regex = Regexp.escape(regex).gsub(/__ASTERISK__/, '.*')
    regex = '^' + regex + '$'

    puts "regex=#{regex}"

    @list.select! {|hostname| hostname.match(regex) }
  end

  def sort_by_domainname
    sortable = {}
    @list.each do |hostname|
      sortable.store(hostname.split(/\./).reverse.join('.'), hostname)
    end
    @list = sortable.keys.sort.collect { |s| sortable[s] }
  end

  def filter_by_runlist_map(runlist_map)
    @list.select! { |hostname| runlist_map.mp.key?(hostname)}
  end

end
