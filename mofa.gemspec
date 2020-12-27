# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "mofa/version"
Gem::Specification.new do |s|
  s.name = "mofa"
  s.version = Mofa::VERSION
  s.authors = ["Alexander Birk"]
  s.email = ["birk@pingworks.de"]
  s.homepage = "https://github.com/pingworks/mofa"
  s.summary = %q{a lightweight remote chef-solo runner}
  s.description = %q{a lightweight remote chef-solo runner}
  s.rubyforge_project = "mofa"
  s.files = `git ls-files`.split("\n")
  s.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
  s.add_development_dependency "rspec"
  s.add_development_dependency "fakefs"
  s.add_development_dependency "guard-minitest"
  s.add_development_dependency "rake"
  s.add_runtime_dependency "thor"
  s.add_runtime_dependency "ed25519"
  s.add_runtime_dependency "bcrypt_pbkdf"
  s.add_runtime_dependency "json"
  s.add_runtime_dependency "rest-client"
  s.add_runtime_dependency "net-ssh"
  s.add_runtime_dependency "net-sftp"
  s.add_runtime_dependency "net-ping"
  s.add_runtime_dependency "user_config"
  s.add_runtime_dependency "chronic"
  s.add_runtime_dependency "win32-security"
end
