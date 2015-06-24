class ReleasedCookbook < Cookbook

  def initialize(cookbook_name_or_path)
    super()
    # TODO: this needs proper vaidation!
    @name = cookbook_name_or_path.split(/@/).first
    @version = cookbook_name_or_path.split(/@/).last
  end

  # ------------- Interface Methods

  def prepare
    @pkg_name ||= "#{name}_#{version}-full.tar.gz"
    @pkg_dir = "#{Mofa::Config.config['tmp_dir']}/#{name}/#{version}/.mofa/#{token}"
  end

  def execute
    # TODO: Download & unpack released cookbook
    # Important for guessing role runlists (when cookbook is an env-cookbook)


  end

  def cleanup
    say "Removing folder #{pkg_dir}...#{nl}"
    run "rm -r #{pkg_dir}"
    ok
  end

  # ------------- /Interface Methods

  def download_and_unpack
    unless File.exist?("#{Mofa::Config.config['tmp_dir']}/#{name}/#{version}/metadata.rb")
      fail unless binrepo_up?
      begin
        Net::SFTP.start(Mofa::Config.config['binrepo_host'],
                        Mofa::Config.config['binrepo_ssh_user'],
                        keys: [Mofa::Config.config['binrepo_ssh_keyfile']],
                        port: Mofa::Config.config['binrepo_ssh_port'],
                        verbose: :error) do |sftp|

          sftp.download!("#{Mofa::Config.config['binrepo_dir']}/#{name}/#{version}/#{@pkg_name}", "#{Mofa::Config.config['tmp_dir']}")


        end
      rescue RuntimeError => e
        puts "Error: #{e.message}"
        raise "Failed to download cookbook #{name}!"
      end
    end
  end

  def cleanup!
    unless (Dir.entries("#{Mofa::Config.config['tmp_dir']}/.mofa") - %w{ . .. }).empty?
      say "Removing content of folder #{Mofa::Config.config['tmp_dir']}/.mofa"
      run "rm -r #{Mofa::Config.config['tmp_dir']}/.mofa/*"
    else
      say "Folder #{Mofa::Config.config['tmp_dir']}/.mofa is (already) clean."
    end
  end

  private

  def nl
    return (Mofa::CLI::option_verbose) ? '' : ' '
  end

end
