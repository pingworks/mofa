require 'rest-client'
require 'net/ping'
require 'json'

class Hostlist
  attr_accessor :list
  attr_accessor :filter
  attr_accessor :service_host
  attr_accessor :service_url
  attr_accessor :api_key
  attr_accessor :concrete_target

  def self.create(filter = nil, service_hostlist_url = nil, concrete_target = nil)
    hl = Hostlist.new
    filter = Mofa::Config.config['service_hostlist_default_filter'] if concrete_target.nil? && filter.nil?
    service_hostlist_url ||= Mofa::Config.config['service_hostlist_url']
    hl.filter = filter
    hl.service_host = Mofa::Config.config['service_hostlist_url'].gsub(/^http:\/\//, '').gsub(/\/.*$/, '').gsub(/:.*$/, '')
    hl.service_url = service_hostlist_url
    hl.api_key = Mofa::Config.config['service_hostlist_api_key']
    hl.concrete_target = concrete_target
    hl
  end

  def self.get_shortname(hostname)
    hostname.gsub(/\..*$/, '')
  end

  def self.get_role(hostname)
    Hostlist::get_shortname(hostname).gsub(/\d+$/, '')
  end

  def has_concrete_target
    return (@concrete_target.nil?) ? false : true
  end

  def retrieve
    case
      when has_concrete_target
        @list = [@concrete_target]
      when @service_url.match(/^http/)
        fail "Hostlist Service not reachable! (cannot ping #{service_host})" unless up?
        response = RestClient.get(@service_url, {:params => {:key => api_key}})
        hosts_list_json = JSON.parse response.body
        @list = hosts_list_json['data'].collect { |i| i['cname'] }
      when @service_url.match(/^file:/)
        json_file = @service_url.gsub(/^file:\/\//, '')
        if File.exist?(json_file)
          hosts_list_json = JSON.parse(File.read(json_file))
          @list = hosts_list_json['data'].collect { |i| i['cname'] }
        else
          fail "Hostlist JSON-File not found: #{json_file}"
        end

      else
        fail "Hostlist Service Url either has to be a http(s):// or a file:/// Url!"
    end
    apply_filter
    sort_by_domainname
  end


  def up?
    p = Net::Ping::TCP.new(@service_host, 'http')
    p.ping?
  end

  def apply_filter
    unless @filter.nil?
      if @filter[0] == '/' && @filter[-1] == '/' && @filter.length > 2
        regex = @filter[1..-2]
      else
        # building matcher
        regex = @filter.gsub(/\*/, '__ASTERISK__')
        regex = Regexp.escape(regex).gsub(/__ASTERISK__/, '.*')
        regex = '^' + regex + '$'
      end
      @list.select! { |hostname| hostname.match(regex) }
    end
  end

  def sort_by_domainname
    sortable = {}
    @list.each do |hostname|
      sortable.store(hostname.split(/\./).reverse.join('.'), hostname)
    end
    @list = sortable.keys.sort.collect { |s| sortable[s] }
  end

  def filter_by_runlist_map(runlist_map)
    @list.select! { |hostname| runlist_map.mp.key?(hostname) }
  end

end
