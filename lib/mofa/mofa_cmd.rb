require 'net/ssh'
require 'net/sftp'

class MofaCmd
  attr_accessor :token
  attr_accessor :cookbook
  attr_accessor :options

  def self.generate_token
    Digest::SHA1.hexdigest([Time.now, rand].join)[0..10]
  end

  def initialize(token, cookbook)
    @token = token
    @cookbook = cookbook
  end

  # @abstract
  def prepare
    raise RuntimeError, "must be implemented"
  end

  # @abstract
  def execute
    raise RuntimeError, "must be implemented"
  end

  # @abstract
  def cleanup
    raise RuntimeError, "must be implemented"
  end

  def ssh_exec!(ssh, command)
    stdout_data = ""
    stderr_data = ""
    exit_code = nil
    exit_signal = nil
    ssh.open_channel do |channel|
      channel.exec(command) do |ch, success|
        unless success
          abort "FAILED: couldn't execute command (ssh.channel.exec)"
        end
        channel.on_data do |ch, data|
          stdout_data+=data
        end

        channel.on_extended_data do |ch, type, data|
          stderr_data+=data
        end

        channel.on_request("exit-status") do |ch, data|
          exit_code = data.read_long
        end

        channel.on_request("exit-signal") do |ch, data|
          exit_signal = data.read_long
        end
      end
    end
    ssh.loop
    [exit_code, stdout_data, stderr_data, exit_signal]
  end

end
