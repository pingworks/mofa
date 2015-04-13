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
    @pkg_dir = "#{Mofa::Config.config['tmp_dir']}/.mofa/#{token}"
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
