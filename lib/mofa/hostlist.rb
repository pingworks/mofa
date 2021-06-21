require 'rest-client'
require 'net/ping'
require 'json'

class Hostlist
  attr_accessor :list
  attr_accessor :concrete_target

  def self.create(concrete_target)
    hl = Hostlist.new
    hl.concrete_target = concrete_target
    hl
  end

  def self.get_shortname(hostname)
    hostname.gsub(/\..*$/, '')
  end

  def self.get_role(hostname)
    Hostlist::get_shortname(hostname).gsub(/\d+$/, '')
  end

  def retrieve
    @list = [@concrete_target]
  end

  def up?
    p = Net::Ping::TCP.new(@service_host, 'http')
    p.ping?
  end

  def filter_by_runlist_map(runlist_map)
    @list.select! { |hostname| runlist_map.mp.key?(hostname) }
  end
end
