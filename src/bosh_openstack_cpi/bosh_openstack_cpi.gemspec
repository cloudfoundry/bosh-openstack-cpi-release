# coding: utf-8
Gem::Specification.new do |s|
  s.name        = 'bosh_openstack_cpi'
  s.version     = '2.1.0'
  s.platform    = Gem::Platform::RUBY
  s.summary     = 'BOSH OpenStack CPI'
  s.description = 'BOSH OpenStack CPI'
  s.author      = 'Piston Cloud Computing / VMware'
  s.homepage    = 'https://github.com/cloudfoundry/bosh'
  s.license     = 'Apache 2.0'
  s.email       = 'support@cloudfoundry.com'
  s.required_ruby_version = Gem::Requirement.new('>= 1.9.3')

  s.files        = Dir['README.md', 'USAGE.md', 'lib/**/*'].select{ |f| File.file? f }
  s.require_path = 'lib'
  s.bindir       = 'bin'
  s.executables  = %w(bosh_openstack_console openstack_cpi)

  # NOTE: Any BOSH gem depencies specified here need to be...
  # 1. without a specific version in this file (to pass BOSH specs)
  # 2. specified within the bosh director and micro gemspecs
  s.add_dependency 'bosh_common'
  s.add_dependency 'bosh_cpi'
  s.add_dependency 'bosh-registry'
  s.add_dependency 'fog',           '~>1.34.0'
  s.add_dependency 'httpclient',    '=2.4.0'
  s.add_dependency 'yajl-ruby',     '>=0.8.2'
  s.add_dependency 'membrane',      '~>1.1.0'
end
