require 'sinatra/base'
require File.join(File.dirname(__FILE__), '../lib/sinatra/cacher')
require 'securerandom'
require 'sinatra/outputbuffer'

class TestApp < Sinatra::Base
  register Sinatra::Cacher
  register Sinatra::OutputBuffer

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

  cache_get '/route_content_type', :tag => :index do
    content_type 'text/plain'
    SecureRandom.uuid
  end

  cache_get '/route_auto_tag/?', :tag => :auto do
    SecureRandom.uuid
  end

  get '/route_block_cache/:type' do |type|
    result = cache_fragment(:block_tag) do
      case type
      when 'hash'; {:uuid => SecureRandom.uuid}
      when 'array'; [:uuid, SecureRandom.uuid]
      when 'string'; "Result of the block: #{SecureRandom.uuid}"
      end
    end
    "CACHED: #{result}: Type #{result.class}\nNOT CAHCED: #{SecureRandom.uuid}"
  end

  get '/route_invalid_block_cache' do
    cache_fragment(:block_tag)
  end

  get '/route_fragment_cache' do
    erb <<-EOF
      NOT CACHED: <%= SecureRandom.uuid%>
      <% cache_fragment(:fragment_tag) do %>
        <p>Hello World</p>
        CACHED: <%= SecureRandom.uuid %>
      <% end %>
    EOF
  end

  get '/route_invalid_fragment_cache' do
    erb "<% cache_fragment(:fragment_tag) %>"
  end
end
