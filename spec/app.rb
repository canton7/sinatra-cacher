require 'sinatra/base'
require File.join(File.dirname(__FILE__), '../lib/sinatra/cacher')
require 'securerandom'

class TestApp < Sinatra::Base
  register Sinatra::Cacher

  set :environment, :test
  set :cache_enabled, true
  set :root, File.dirname(__FILE__)

  cache_get '/route_no_tag' do
    SecureRandom.uuid
  end

  cache_get '/route_explicit_tag', :tag => :index do
    SecureRandom.uuid
  end

  cache_get '/route_arg_tag/:arg' do |arg|
    cache_tag arg unless arg == 'dont_cache'
    SecureRandom.uuid
  end
end