# -*- encoding: utf-8 -*-
# stub: user_config 0.0.4 ruby lib

Gem::Specification.new do |s|
  s.name = "user_config".freeze
  s.version = "0.0.4"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Takayuki YAMAGUCHI".freeze]
  s.date = "2012-01-05"
  s.description = "The library creates, saves, and loads configuration files, which are in a user's home directory or a specified directory.".freeze
  s.email = ["d@ytak.info".freeze]
  s.homepage = "".freeze
  s.rubygems_version = "3.0.3".freeze
  s.summary = "Management of configuration files in a user's home directory".freeze

  s.installed_by_version = "3.0.3" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<rspec>.freeze, [">= 0"])
      s.add_development_dependency(%q<yard>.freeze, [">= 0"])
    else
      s.add_dependency(%q<rspec>.freeze, [">= 0"])
      s.add_dependency(%q<yard>.freeze, [">= 0"])
    end
  else
    s.add_dependency(%q<rspec>.freeze, [">= 0"])
    s.add_dependency(%q<yard>.freeze, [">= 0"])
  end
end
