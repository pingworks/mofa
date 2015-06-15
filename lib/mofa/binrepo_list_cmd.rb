require 'net/ssh'
require 'net/sftp'

class BinrepoListCmd < MofaCmd

  def prepare
    fail unless binrepo_up?
  end

  def execute
    list_binrepo_content
  end

  def cleanup
  end

  def list_binrepo_content
    puts "Will use ssh_user #{Mofa::Config.config['binrepo_ssh_user']} and ssh_key_file #{Mofa::Config.config['binrepo_ssh_keyfile']}"

    begin

      Net::SSH.start(Mofa::Config.config['binrepo_host'],
                     Mofa::Config.config['binrepo_ssh_user'],
                     keys: [Mofa::Config.config['binrepo_ssh_keyfile']],
                     port: Mofa::Config.config['binrepo_ssh_port'],
                     verbose: :error,
                     use_agent: false) do |ssh|
        out = ssh_exec!(ssh, "ls -al")
        fail "ERROR (#{out[0]}): #{out[2]}" if out[0] != 0
      end

    rescue RuntimeError => e
      puts "Error: #{e.message}"
      raise "Failed to list binrepo content!"
    end
  end
end
