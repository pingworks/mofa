class ReleasedCookbook < Cookbook

  def self.get_name_and_version(cookbook_name_or_path)
    # TODO: this needs proper vaidation!
    name = cookbook_name_or_path.split(/@/).first
    version = cookbook_name_or_path.split(/@/).last
    { 'name' => name, 'version' => version }
  end

  def self.exists?(cookbook_name_or_path)
    nv = get_name_and_version(cookbook_name_or_path)
    url = "#{Mofa::Config.config['bin_repo']}/#{nv['name']}/#{nv['version']}/#{nv['name']}_#{nv['version']}-full.tar.gz"
    puts "Checking if cookbook exists: #{url}"
    RestClient.head(url)
  end

  def initialize(cookbook_name_or_path)
    super()
    nv = ReleasedCookbook.get_name_and_version(cookbook_name_or_path)
    @name = nv['name']
    @version = nv['version']
  end

  # ------------- Interface Methods

  def prepare
    @pkg_name ||= "#{name}_#{version}-full.tar.gz"
    @pkg_dir = "#{Mofa::Config.config['tmp_dir']}/.mofa/#{token}"
    set_cookbooks_url
  end

  def execute#
    package
  end

  def cleanup
    say "Removing folder #{pkg_dir}...#{nl}"
    run "rm -rf #{pkg_dir}"
    ok
  end

  def package
    mkdir_p @pkg_dir
    say "Downloading released cookbook from: #{cookbooks_url} to #{pkg_dir}/#{pkg_name}..."
    File.open("#{pkg_dir}/#{pkg_name}", "wb") do |saved_file|
      # the following "open" is provided by open-uri
      open(cookbooks_url, "rb") do |read_file|
        saved_file.write(read_file.read)
      end
    end
  end

  def load_mofa_yml
    @mofa_yml = MofaYml.load_from_file(".mofa.yml", self)
  end

  def load_mofa_yml_local
    @mofa_yml_local = MofaYml.load_from_file(".mofa.local.yml", self)
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

  def set_cookbooks_url
    say 'Using remote URI as cookbooks_url: '
    @cookbooks_url = "#{Mofa::Config.config['bin_repo']}/#{@name}/#{@version}/#{@name}_#{@version}-full.tar.gz"
    say "#{@cookbooks_url}"
  end

  def recipes
    []
  end

  private

  def nl
    return (Mofa::CLI::option_verbose) ? '' : ' '
  end

end
