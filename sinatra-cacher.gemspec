$: << (File.dirname(__FILE__))
require 'lib/sinatra/cacher'

spec = Gem::Specification.new do |s|
  s.name = 'sinatra-cacher'
  s.version = Sinatra::Cacher::VERSION
  s.summary = 'Simple and effective file-based caching for sinatra'
  s.description = 'Caches routes, blocks, or HTML fragments. Sets etag correctly. Automatic or manual tag generation. Easy cache clearing.'
  s.platform = Gem::Platform::RUBY
  s.authors = ['Antony Male']
  s.email = 'antony dot mail at gmail'
  s.required_ruby_version = '>= 1.9.2'
  s.homepage = 'https://github.com/canton7/sinatra-cacher'

  s.files = Dir['lib/**/*']
end
