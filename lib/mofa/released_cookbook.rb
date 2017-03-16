class ReleasedCookbook < Cookbook

  def self.get_name_and_version(cookbook_name_or_path)
    # TODO: this needs proper vaidation!
    name = cookbook_name_or_path.split(/@/).first
    version = cookbook_name_or_path.split(/@/).last
    { 'name' => name, 'version' => version }
  end

  def self.exists?(cookbook_name_or_path)
    nv = get_name_and_version(cookbook_name_or_path)
    url = "#{Mofa::Config.config['binrepo_base_url']}/#{nv['name']}/#{nv['version']}/#{nv['name']}_#{nv['version']}-full.tar.gz"
    puts "Checking if cookbook exists: #{url}"
    RestClient.head(url)
  end

  def initialize(cookbook_name_or_path, override_mofa_secrets = nil)
    super()
    nv = ReleasedCookbook.get_name_and_version(cookbook_name_or_path)
    @name = nv['name']
    @version = nv['version']
    @override_mofa_secrets = override_mofa_secrets
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
    tar_verbose = (Mofa::CLI::option_debug) ? 'v' : ''
    mkdir_p @pkg_dir
    say "Downloading released cookbook from: #{cookbooks_url} to #{pkg_dir}/#{pkg_name}..."
    File.open("#{pkg_dir}/#{pkg_name}", "wb") do |saved_file|
      # the following "open" is provided by open-uri
      open(cookbooks_url, "rb") do |read_file|
        saved_file.write(read_file.read)
      end
    end
    mkdir_p "#{pkg_dir}/tmp"
    run "tar x#{tar_verbose}fz #{pkg_dir}/#{pkg_name} -C #{pkg_dir}/tmp/"

    # copy out data_bags if exists
    if File.directory?("#{pkg_dir}/tmp/cookbooks/#{name}/data_bags")
      FileUtils.cp_r "#{pkg_dir}/tmp/cookbooks/#{name}/data_bags", pkg_dir
    end

    # copy out recipes
    if File.directory?("#{pkg_dir}/tmp/cookbooks/#{name}/recipes")
      FileUtils.cp_r "#{pkg_dir}/tmp/cookbooks/#{name}/recipes", pkg_dir
    end

    # Sync in mofa_secrets
    if override_mofa_secrets
      run "rsync -avx #{override_mofa_secrets}/ #{pkg_dir}/tmp/cookbooks/#{name}/"
    end

    if File.exist?("#{pkg_dir}/tmp/cookbooks/#{name}/.mofa.yml")
      FileUtils.cp "#{pkg_dir}/tmp/cookbooks/#{name}/.mofa.yml", pkg_dir
    end

    if File.exist?("#{pkg_dir}/tmp/cookbooks/#{name}/.mofa.local.yml")
      FileUtils.cp "#{pkg_dir}/tmp/cookbooks/#{name}/.mofa.local.yml", pkg_dir
    end

    run "cd #{pkg_dir}/tmp/;tar c#{tar_verbose}fz #{pkg_dir}/#{pkg_name}.new ."
    run "rm #{pkg_dir}/#{pkg_name}"
    run "mv #{pkg_dir}/#{pkg_name}.new #{pkg_dir}/#{pkg_name}"
    run "rm -rf #{pkg_dir}/tmp/"
  end

  def load_mofa_yml
    @mofa_yml = MofaYml.load_from_file("#{pkg_dir}/.mofa.yml", self)
  end

  def load_mofa_yml_local
    @mofa_yml_local = MofaYml.load_from_file("#{pkg_dir}/.mofa.local.yml", self)
  end

  # ------------- /Interface Methods
  def source_dir
    "#{pkg_dir}"
  end

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
    @cookbooks_url = "#{Mofa::Config.config['binrepo_base_url']}/#{@name}/#{@version}/#{@name}_#{@version}-full.tar.gz"
    say "#{@cookbooks_url}"
  end

  def recipes
    raise 'Cookbook not unpacked yet or no recipes found.' unless (Dir.exists?("#{pkg_dir}/recipes"))
    recipes = Dir.entries("#{pkg_dir}/recipes").select { |f| f.match(/.rb$/) }
    recipes.map! { |f| f.gsub(/\.rb/, '') }
  end

  private

  def nl
    return (Mofa::CLI::option_verbose) ? '' : ' '
  end

end
