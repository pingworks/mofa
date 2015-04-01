class SourceCookbook < Cookbook
  attr_accessor :pkg_dir
  attr_accessor :pkg_name

  COOKBOOK_IGNORE=%w(.mofa .idea .kitchen .vagrant .bundle test)

  def initialize(cookbook_name_or_path)
    super()
    path = Pathname.new(cookbook_name_or_path)

    say "Looking for Cookbook Sources in Path #{path}..."
    @source_uri = "file://#{path.realpath}"

    say "source_dir=#{source_dir}"
    autodetect_name
    autodetect_version
  end

  # ------------- Interface Methods

  def prepare
    fail "Source URI is not a file:// URI!" unless source_uri =~ /^file:\/\/.*/
    fail "Folder #{source_dir} is not a Cookbook Folder!" unless cookbook_folder?(source_dir)
    @pkg_name = "#{name}-#{token}-SNAPSHOT.tar.gz"
    @pkg_dir = "#{source_dir}/.mofa/#{token}"
  end

  def execute
    package
    stage
  end

  def cleanup
    say "Removing folder #{pkg_dir}...#{nl}"
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
    unless (Dir.entries("#{source_dir}/.mofa") - %w{ . .. }).empty?
      say "Removing content of folder #{source_dir}/.mofa"
      run "rm -r #{source_dir}/.mofa/*"
    else
      say "Folder #{source_dir}/.mofa is (already) clean."
    end
  end

  def stage
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
    say "Running \"berks install\" and \”berks package\" on Cookbook in #{source_dir}...#{nl}"

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
    say "Shrinking Cookbook Snapshot #{pkg_name}...#{nl}"

    tar_verbose = (Mofa::CLI::option_debug) ? 'v' : ''

    inside source_dir do

      mkdir_p "#{pkg_dir}/tmp"
      run "tar x#{tar_verbose}fz #{pkg_dir}/#{pkg_name} -C #{pkg_dir}/tmp/"

      COOKBOOK_IGNORE.each do |remove_this|
        if File.exists?("#{pkg_dir}/tmp/cookbooks/#{name}/#{remove_this}")
          run "rm -r #{pkg_dir}/tmp/cookbooks/#{name}/#{remove_this}"
        end
      end

      run "cd #{pkg_dir}/tmp/;tar c#{tar_verbose}fz #{pkg_dir}/#{pkg_name}.new ."
      run "rm #{pkg_dir}/#{pkg_name}"
      run "mv #{pkg_dir}/#{pkg_name}.new #{pkg_dir}/#{pkg_name}"
      run "rm -r #{pkg_dir}/tmp/"

    end

    ok
  end

  private

  def nl
    return (Mofa::CLI::option_verbose) ? '' : ' '
  end
end
