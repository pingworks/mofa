require 'mofa'
require 'thor'
require 'yaml'

module Mofa
  class CLI < Thor
    include Thor::Actions
    include Mofa::Config

    @@option_verbose = false
    @@option_debug = false

    class_option :verbose, :type => :boolean, :aliases => '-v', :desc => 'be verbose'
    class_option :debug, :type => :boolean, :aliases => '-vv', :desc => 'be very vebose'

    desc 'provision <cookbook>', 'provisions Targethost(s) using a given cookbook.'
    method_option :target, :type => :string, :aliases => '-t'
    method_option :runlist, :type => :string, :aliases => '-o'

    Mofa::Config.load

    def provision(cookbook_name_or_path)
      set_verbosity

      cookbook_name_or_path ||= '.'

      target_filter = options[:target]
      target_filter ||= Mofa::Config.config['profiles']['default']['target']

      token = MofaCmd.generate_token

      hostlist = Hostlist.create(target_filter)
      cookbook = Cookbook.create(cookbook_name_or_path, token)
      runlist_map = RunlistMap.create(cookbook, hostlist, token, options[:runlist])
      attributes_map = AttributesMap.create(cookbook, hostlist, token, options[:runlist], options[:attributes])

      mofa_cmd = MofaCmd.create(cookbook, hostlist, runlist_map, attributes_map, token)

      mofa_cmd.prepare
      mofa_cmd.execute
      mofa_cmd.cleanup

    end

    desc 'config', 'prints out mofa config.'

    def config
      config_print
    end

    desc 'setup', 'setup initial configuration'

    def setup
      set_verbosity

      case
        when !File.exists?("#{ENV['HOME']}/.mofa/config.yml")
          begin
            config_create
          end until config_valid?
        else
          begin
            config_edit
          end until config_valid?
      end
    end

    def self.option_verbose
      @@option_verbose
    end

    def self.option_debug
      @@option_debug
    end

    private
    # Private methods go in here
    def set_verbosity
      @@option_debug = (options[:debug]) ? true : false
      @@option_verbose = (options[:verbose] || options[:debug]) ? true : false
    end

    def em(text)
      shell.set_color(text, nil, true)
    end

    def ok(detail=nil)
      text = detail ? "OK, #{detail}." : "OK."
      say text, :green
    end

    def error(detail)
      say detail, :red
    end

    def config_create
      say 'Creating a new mofa config (~/.mofa/config.yml)...'

      say '- not implemented yet -'

    end

    def config_edit
      say 'Editing mofa config (~/.mofa/config.yml)...'

      say '- not implemented yet -'

    end

    def config_print
      say 'Mofa Config (~/.mofa/config.yml):'

      say '- not implemented yet -'

    end

    def config_valid?
      say 'Validating Mofa config (~/.mofa/config.yml)...'
      say '- not implemented yet -'
      true
    end


  end
end
