require 'net/ssh'
require 'net/sftp'

class UploadCmd < MofaCmd

  def initialize(token, cookbook)
    super(token, cookbook)
  end

  def prepare
    fail unless binrepo_up?

    # upload always means: package a release
    cookbook.pkg_name = "#{cookbook.name}_#{cookbook.version}-full.tar.gz"
    cookbook.prepare
  end

  def execute
    cookbook.execute
    upload_cookbook_pkg
  end

  def cleanup
    cookbook.cleanup
  end

  def binrepo_up?
    binrepo_up = true

    exit_status = system("ping -q -c 1 #{Mofa::Config.config['binrepo_host']} >/dev/null 2>&1")
    unless exit_status then
      puts "  --> Binrepo host #{Mofa::Config.config['binrepo_host']} is unavailable!"
      binrepo_up = false
    end

    puts "Binrepo #{ Mofa::Config.config['binrepo_ssh_user']}@#{Mofa::Config.config['binrepo_host']}:#{Mofa::Config.config['binrepo_import_dir']} not present or not reachable!" unless binrepo_up
    binrepo_up

  end

  def upload_cookbook_pkg
    puts "Will use ssh_user #{Mofa::Config.config['binrepo_ssh_user']} and ssh_key_file #{Mofa::Config.config['binrepo_ssh_keyfile']}"
    puts "Uploading cookbook pkg #{cookbook.pkg_name} to binrepo import folder #{Mofa::Config.config['binrepo_host']}:#{Mofa::Config.config['binrepo_import_dir']}..."

    fail unless binrepo_up?
    begin
      Net::SFTP.start(Mofa::Config.config['binrepo_host'], Mofa::Config.config['binrepo_ssh_user'], :keys => [Mofa::Config.config['binrepo_ssh_keyfile']], :port => Mofa::Config.config['binrepo_ssh_port'], :verbose => :error) do |sftp|
        sftp.upload!("#{cookbook.pkg_dir}/#{cookbook.pkg_name}", "#{Mofa::Config.config['binrepo_import_dir']}/#{cookbook.pkg_name}")
      end
      puts "OK."
    rescue RuntimeError => e
      puts "Error: #{e.message}"
      raise "Failed to upload cookbook #{cookbook.name}!"
    end

  end

end
