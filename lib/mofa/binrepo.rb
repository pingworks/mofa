require 'mofa'
require 'thor'
require 'yaml'

module Mofa
  # rubocop:disable ClassLength
  class Binrepo < Thor
    include Thor::Actions
    include Mofa::Config

    Mofa::Config.load

    @@option_verbose = false
    @@option_debug = false

    class_option :verbose, type: :boolean, aliases: '-v', desc: 'be verbose'
    class_option :debug, type: :boolean, aliases: '-vv', desc: 'be very vebose'

    desc 'list', 'list binrepo content'
    method_option :binrepo_host, type: :string
    method_option :binrepo_ssh_user, type: :string
    method_option :binrepo_ssh_keyfile, type: :string

    def list
      cmd = BinrepoListCmd.new

      cmd.prepare
      cmd.execute
      cmd.cleanup

    end

  end
end
