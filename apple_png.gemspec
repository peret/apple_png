Gem::Specification.new do |s|
  s.name        = 'apple_png'
  s.version     = '0.1.4'
  s.date        = '2015-12-22'
  s.summary     = "Converts the Apple PNG format to standard PNG"
  s.description = "Converts the Apple PNG format used in iOS packages to standard PNG"
  s.authors     = ["Peter Retzlaff"]
  s.email       = 'pe.retzlaff@gmail.com'
  s.files       = ["lib/apple_png.rb"] + Dir.glob('ext/**/*.{c,h,rb}')
  s.extensions  = ['ext/apple_png/extconf.rb']
  s.homepage    =
    'http://rubygems.org/gems/apple_png'
end