# -*- encoding: utf-8 -*-
$:.push File.expand_path('../lib', __FILE__)
require 'tunnels/version'

Gem::Specification.new do |s|
  s.name        = 'multitunnels'
  s.version     = Tunnels::VERSION
  s.authors     = ['jugyo', 'bachue']
  s.email       = ['jugyo.org@gmail.com', 'bachue.shu@gmail.com']
  s.homepage    = "https://github.com/bachue/tunnels"
  s.summary     = %q{https/http --(--)--> https/http}
  s.description = %q{This tunnels http/https to http/https.}

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ['lib']

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'rr'
  s.add_runtime_dependency 'eventmachine'
end
