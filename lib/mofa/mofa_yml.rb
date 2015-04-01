class MofaYml
  attr_accessor :cookbook
  attr_accessor :yml

  def initialize
    @yml = {}
  end

  def self.load_from_file(path_to_mofayml, cookbook)
    mfyml = MofaYml.new
    mfyml.cookbook = cookbook
    if File.exist?(path_to_mofayml)
      mfyml.parse_and_load(path_to_mofayml)
    end
    mfyml
  end

  def get_attr_for_role(role_name)
    attr = {}
    if @yml.key?('roles') # && @yml['roles'].kind_of?(Array)
      @yml['roles'].each do |role|
        if role.key?('name') && role['name'] == role_name
          if role.key?('attributes')
            attr = role['attributes']
          end
        end
      end
    end
    attr
  end

  def parse_and_load(path_to_mofayml)
    # for now only __ENV_COOKBOOK__ for cookbook name is supported
    file_contents = File.read(path_to_mofayml)
    file_contents.gsub!(/__ENV_COOKBOOK__/, @cookbook.name)
    puts "FileContents: #{file_contents}"
    @yml = YAML.load(file_contents)
    puts "Parsed: #{@yml}"
  end
end
