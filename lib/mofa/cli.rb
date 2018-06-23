require 'mofa'
require 'thor'
require 'yaml'

module Mofa
  class CLI < Thor
    include Thor::Actions
    include Mofa::Config

    Mofa::Config.load

    @@option_verbose = false
    @@option_debug = false

    class_option :verbose, :type => :boolean, :aliases => '-v', :desc => 'be verbose'
    class_option :debug, :type => :boolean, :aliases => '-vv', :desc => 'be very vebose'

    desc 'provision <cookbook>', 'provisions Targethost(s) using a given cookbook.'
    method_option :ignore_ping, :type => :boolean, :aliases => '-p'
    method_option :target, :type => :string, :aliases => '-t'
    method_option :concrete_target, :type => :string, :aliases => '-T'
    method_option :sshport, :type => :string, :aliases => '-P'
    method_option :runlist, :type => :string, :aliases => '-o'
    method_option :attributes, :type => :string, :aliases => '-j'
    method_option :service_hostlist_url, :type => :string
    method_option :override_mofa_secrets, :type => :string, :aliases => '-S'

    def provision(cookbook_name_or_path)
      set_verbosity

      cookbook_name_or_path ||= '.'

      target_filter = options[:target]
      #target_filter ||= Mofa::Config.config['profiles']['default']['target']

      token = MofaCmd.generate_token

      hostlist = Hostlist.create(target_filter, options[:service_hostlist_url], options[:concrete_target])
      cookbook = Cookbook.create(cookbook_name_or_path, token, options[:override_mofa_secrets])
      runlist_map = RunlistMap.create(cookbook, hostlist, token, options[:runlist])
      attributes_map = AttributesMap.create(cookbook, hostlist, token, options[:runlist], options[:attributes])

      cmd = ProvisionCmd.new(token, cookbook)

      cmd.hostlist = hostlist
      cmd.runlist_map = runlist_map
      cmd.attributes_map = attributes_map
      cmd.options = options

      cmd.prepare
      cmd.execute(options[:sshport])
      cmd.cleanup
    end

    desc 'upload <cookbook>', 'package & upload cookbook into binrepo'
    method_option :binrepo_host, :type => :string
    method_option :binrepo_sshport, :type => :string
    method_option :binrepo_ssh_user, :type => :string
    method_option :binrepo_ssh_keyfile, :type => :string

    def upload(cookbook_path)
      set_verbosity

      cookbook_path ||= '.'

      token = MofaCmd.generate_token
      cookbook = Cookbook.create(cookbook_path, token)

      cmd = UploadCmd.new(token, cookbook)

      cmd.prepare
      # FIXME: bring in the ssh-port in a different way
      cmd.execute(22)
      cmd.cleanup
    end

    desc 'version', 'prints out mofa version.'

    def version
      puts VERSION
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

    def self.exit_on_failure?
      true
    end

  end
end
