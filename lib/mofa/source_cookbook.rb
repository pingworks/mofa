class SourceCookbook < Cookbook
  COOKBOOK_IGNORE = %w(.mofa .idea .kitchen .vagrant .bundle test .git)

  def initialize(cookbook_name_or_path, override_mofa_secrets = nil)
    super()
    path = Pathname.new(cookbook_name_or_path)

    say "Looking for Cookbook Sources in Path #{path}..."
    @source_uri = "file://#{path.realpath}"

    say "source_dir=#{source_dir}"

    @override_mofa_secrets = override_mofa_secrets

    autodetect_name
    autodetect_version
  end

  # ------------- Interface Methods

  def prepare
    fail "Source URI is not a file:// URI!" unless source_uri =~ /^file:\/\/.*/
    fail "Folder #{source_dir} is not a Cookbook Folder!" unless cookbook_folder?(source_dir)

    @pkg_name ||= "#{name}_#{version}-SNAPSHOT.tar.gz"
    @pkg_dir = "#{source_dir}/.mofa/#{token}"

    set_cookbooks_url
  end

  def execute
    package
  end

  def cleanup
    say "Removing folder #{pkg_dir}... "
    run "rm -r #{pkg_dir}"
    ok
  end

  # ------------- /Interface Methods

  def source_dir
    source_uri.gsub(/^file:\/\//, '')
  end

  def load_mofa_yml
    @mofa_yml = MofaYml.load_from_file("#{source_dir}/.mofa.yml", self)
  end

  def load_mofa_yml_local
    if override_mofa_secrets
      say "-S Switch found - checking for .mofa.local.yml..."
      if File.file?("#{override_mofa_secrets}/#{name}/.mofa.local.yml")
        say ".mofa.local.yml found at #{override_mofa_secrets}/#{name}/.mofa.local.yml - copying it into source dir..."
        FileUtils.cp "#{override_mofa_secrets}/#{name}/.mofa.local.yml", "#{source_dir}/.mofa.local.yml"
      end
    end
    @mofa_yml_local = MofaYml.load_from_file("#{source_dir}/.mofa.local.yml", self)
  end

  def autodetect_name
    say "Autodetecting Cookbook Name... "
    @name = open("#{source_dir}/metadata.rb").grep(/^name/)[0].gsub(/^name[^a-zA-Z0-9_-]*/, '').gsub(/.$/, '').chomp
    say "#{name}"
  end

  def autodetect_version
    say "Autodetecting Cookbook Version... "
    @version = open("#{source_dir}/metadata.rb").grep(/^version/)[0].gsub(/^version[^0-9\.]*/, '').gsub(/.$/, '').chomp
    say "#{version}"
  end

  def recipes
    recipes = Dir.entries("#{source_dir}/recipes").select { |f| f.match(/.rb$/) }
    recipes.map! { |f| f.gsub(/\.rb/, '') }
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
    if mofahub_available?
      say 'Staging (uploading to mofa-hub) Cookbook Snapshot: '
      @cookbooks_url = upload_to_mofahub
    else
      say 'Using local URI as cookbooks_url: '
      @cookbooks_url = "file://#{pkg_dir}/#{pkg_name}"
    end
    say "#{@cookbooks_url}"
  end

  def cookbook_folder?(source_dir)
    File.exist?(source_dir) && File.exists?("#{source_dir}/metadata.rb") && File.exists?("#{source_dir}/recipes")
  end

  def mofahub_available?
    false
  end

  def package
    berks_install_package
    cleanup_and_repackage
  end

  def berks_install_package
    say "Running \"berks install\" and \"berks package\" on Cookbook in #{source_dir}...#{nl}"

    redirect_stdout = (Mofa::CLI::option_verbose) ? '' : '> /dev/null'
    Bundler.with_clean_env do
      inside source_dir do
        mkdir_p pkg_dir
        run "berks install #{redirect_stdout}"
        run "berks package #{pkg_dir}/#{pkg_name} #{redirect_stdout}"
      end
    end

    ok
  end

  def cleanup_and_repackage
    say "Shrinking Cookbook #{pkg_name}... "

    tar_verbose = (Mofa::CLI::option_debug) ? 'v' : ''

    inside pkg_dir do
      empty_directory 'tmp'
      run "tar x#{tar_verbose}fz #{pkg_name} -C tmp/"

      COOKBOOK_IGNORE.each do |remove_this|
        if File.exists?("tmp/cookbooks/#{name}/#{remove_this}")
          run "rm -rf tmp/cookbooks/#{name}/#{remove_this}"
        end
      end
    end
    inside "#{pkg_dir}/tmp" do
      # Sync in mofa_secrets
      if override_mofa_secrets
        if File.directory?("#{override_mofa_secrets}/#{name}/cookbooks")
          run "rsync -vr #{override_mofa_secrets}/#{name}/cookbooks/ cookbooks/"
        end
      end
    end
    inside "#{pkg_dir}/tmp" do
      run "tar c#{tar_verbose}fz ../#{pkg_name}.new ."
    end
    inside pkg_dir do
      run "rm #{pkg_name}"
      run "mv #{pkg_name}.new #{pkg_name}"
      run 'rm -rf tmp/'
    end

    ok
  end

  private

  def nl
    return (Mofa::CLI::option_verbose) ? '' : ' '
  end
end
