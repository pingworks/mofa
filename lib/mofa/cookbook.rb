require 'pathname'
require 'thor/base'
require 'thor/actions'

class Cookbook
  include Thor::Base
  include Thor::Actions
  include FileUtils

  attr_accessor :name
  attr_accessor :version
  attr_accessor :type
  attr_accessor :pkg_name
  attr_accessor :pkg_dir
  attr_accessor :pkg_uri
  attr_accessor :source_uri
  attr_accessor :cookbooks_url
  attr_accessor :mofa_yml
  attr_accessor :mofa_yml_local
  attr_accessor :token

  def self.create(cookbook_name_or_path, token)
    cookbook = nil
    begin
      case
      when cookbook_name_or_path.match(/@/)
        fail "Did not find released Cookbook #{cookbook_name_or_path}!" unless ReleasedCookbook.exists?(cookbook_name_or_path)
        fail "Did not find Version #{cookbook_version} of released Cookbook #{cookbook_name_or_path}!" unless ReleasedCookbook.exists?(cookbook_name_or_path, cookbook_version)

        cookbook = ReleasedCookbook.new(cookbook_name_or_path)
      else
        cookbook = SourceCookbook.new(cookbook_name_or_path)
      end
    rescue RuntimeError => e
      error e.message
      raise "Cookbook not found/detected!"
    end
    cookbook.token = token
    cookbook.autodetect_type
    cookbook.load_mofa_yml
    cookbook.load_mofa_yml_local
    cookbook
  end

  def autodetect_type
    env_indicator = Mofa::Config.config['cookbook_type_indicator']['env']
    wrapper_indicator = Mofa::Config.config['cookbook_type_indicator']['wrapper']
    base_indicator = Mofa::Config.config['cookbook_type_indicator']['base']

    say "Autodetecting Cookbook Architectural Type... "

    case
      when @name.match(env_indicator)
        @type = 'env'
      when @name.match(base_indicator)
        @type = 'base'
      when @name.match(wrapper_indicator)
        @type = 'wrapper'
      else
        @type = 'application'
    end
    say "#{type.capitalize} Cookbook"
  end

  def say(message = "", color = nil, force_new_line = (message.to_s !~ /( |\t)$/))
    color ||= :green
    super
  end

  def ok(detail=nil)
    text = detail ? "OK, #{detail}." : "OK."
    say text, :green
  end

  def error(detail)
    say detail, :red
  end

  # Enforce silent system calls, unless the --verbose option is passed.
  # One may either pass -v, --verbose or --[v|verbose]=[true|t|yes|y|1].
  #
  def run(cmd, *args)
    args = args.empty? ? {} : args.pop
    verbose = (Mofa::CLI::option_debug) ? true : false
    #verbose = !!(options[:verbose] && options[:verbose].to_s.match(/(verbose|true|t|yes|y|1)$/i))
    exit_code = super(cmd, args.merge(verbose: verbose))
    fail "Failed to run #{cmd.inspect}!" unless exit_code == true
  end


end
