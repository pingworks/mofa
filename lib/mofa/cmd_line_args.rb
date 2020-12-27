module Mofa
  class CmdLineArgs
    def self.instance
      @__instance__ ||= new
    end

    def initialize
      @cmd_line_args = {}
    end

    def register(cmd_line_args)
      @cmd_line_args = cmd_line_args
    end

    def get(key)
      raise "Cmd Line Arg with key #{key} does not exist!" unless @cmd_line_args.key?(key)
      @cmd_line_args[key]
    end

    def list
    puts 'Comman Line Args:'
    @cmd_line_args.inspect
    end
  end
end
