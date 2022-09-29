Gem::Specification.new do |s|
  s.name = 'acts_as_feedable'
  s.version = '1.1.0'
  s.date = %q{2013-08-09}
  s.email = 'technical@rrnpilot.org'
  s.homepage = 'http://github.com/rrn/acts_as_feedable'
  s.summary = 'Allows objects to create feeds which describe them'
  s.description = 'Allows objects to create feeds which describe them. These feeds can then be used in a "Facebook-style" News Feed.'
  s.authors = ['Ryan Wallace', 'Nicholas Jakobsen']
  s.require_path = "lib"
  s.files = Dir.glob("{app,lib}/**/*") + %w(README.rdoc)

  s.add_dependency('rails', '>= 4.2')
end
