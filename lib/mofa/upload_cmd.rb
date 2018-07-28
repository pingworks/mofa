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

  def execute(_ssh_port)
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

    fail unless binrepo_up?
    import_dir = Mofa::Config.config['binrepo_import_dir']

    begin
      # if the upload target is not a proper binrepo with a designated ".../import" folder -> create the "right" folder structure
      unless Mofa::Config.config['binrepo_import_dir'].match(/import$/)
        Net::SSH.start(Mofa::Config.config['binrepo_host'],
                       Mofa::Config.config['binrepo_ssh_user'],
                       :keys => [Mofa::Config.config['binrepo_ssh_keyfile']],
                       :port => Mofa::Config.config['binrepo_ssh_port'],
                       :verbose => :error,
                       :use_agent => false) do |ssh|
          puts "Remotely creating target dir \"#{import_dir}/#{cookbook.name}/#{cookbook.version}\""
          out = ssh_exec!(ssh, "[ -d #{import_dir}/#{cookbook.name}/#{cookbook.version} ] || mkdir -p #{import_dir}/#{cookbook.name}/#{cookbook.version}")
          fail "ERROR (#{out[0]}): #{out[2]}" if out[0] != 0
          import_dir = "#{import_dir}/#{cookbook.name}/#{cookbook.version}"
        end
      end

      # only upload if the file does not exist on the target host:
      already_uploaded = false
      Net::SSH.start(Mofa::Config.config['binrepo_host'],
                     Mofa::Config.config['binrepo_ssh_user'],
                     :keys => [Mofa::Config.config['binrepo_ssh_keyfile']],
                     :port => Mofa::Config.config['binrepo_ssh_port'],
                     :verbose => :error,
                     :use_agent => false) do |ssh|
        out = ssh_exec!(ssh, "if [ -f #{import_dir}/#{cookbook.pkg_name} ];then echo -n already_exists;fi")
        fail "ERROR (#{out[0]}): #{out[2]}" if out[0] != 0
        already_uploaded = true if out[1] == 'already_exists'
      end

      unless already_uploaded
        puts "Uploading cookbook pkg #{cookbook.pkg_name} to binrepo import folder #{Mofa::Config.config['binrepo_host']}:#{Mofa::Config.config['binrepo_import_dir']}..."
        Net::SFTP.start(Mofa::Config.config['binrepo_host'],
                        Mofa::Config.config['binrepo_ssh_user'],
                        :keys => [Mofa::Config.config['binrepo_ssh_keyfile']],
                        :port => Mofa::Config.config['binrepo_ssh_port'],
                        :verbose => :error,
                        :use_agent => false) do |sftp|
          sftp.upload!("#{cookbook.pkg_dir}/#{cookbook.pkg_name}", "#{import_dir}/#{cookbook.pkg_name}")
        end
        puts "OK."
      else
        puts "Cookbook pkg #{cookbook.pkg_name} already exists in the binrepo. Will NOT upload it again."
      end
    rescue RuntimeError => e
      puts "Error: #{e.message}"
      raise "Failed to upload cookbook #{cookbook.name}!"
    end
  end
end
