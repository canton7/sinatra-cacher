require 'rack/test'
require File.join(File.dirname(__FILE__), 'app')
require 'fileutils'

describe "Sinatra-cacher" do
  include Rack::Test::Methods

  def app
    TestApp
  end

  after do
    FileUtils.rm_rf(File.join(File.dirname(__FILE__), 'tmp'))
  end

  it "should not cache if no tag is given" do
    get '/route_no_tag'
    response_1 = last_response.body
    get '/route_no_tag'
    last_response.status.should == 200
    response_1.should_not == last_response.body
  end

  it "should cache if a route parameter is given" do
    get '/route_explicit_tag'
    response_1 = last_response.body
    get '/route_explicit_tag'
    response_1.should == last_response.body
  end

  it "should set an etag header, and return 304 correctly" do
    get '/route_explicit_tag'
    etag = last_response.headers['ETag']
    etag.should_not == nil
    response_1 = last_response.body
    get '/route_explicit_tag', {}, 'HTTP_IF_NONE_MATCH' => etag
    last_response.status.should == 304
    last_response.body.should  == ''
    get '/route_explicit_tag', {}, 'HTTP_IF_NONT_MATCH' => 'dummy_etag'
    last_response.status.should == 200
    last_response.headers['ETag'].should == etag
    last_response.body.should == response_1
  end

  it "should cache correctly if #cache_tag is used" do
    get '/route_arg_tag/tag1'
    response_1 = last_response.body
    last_response.status.should == 200
    get '/route_arg_tag/tag1'
    last_response.body.should == response_1
    get '/route_arg_tag/tag2'
    response_2 = last_response.body
    response_1.should_not == response_2
    get '/route_arg_tag/tag2'
    last_response.body.should == response_2
    get '/route_arg_tag/dont_cache'
    response_3 = last_response.body
    get '/route_arg_tag/dont_cache'
    last_response.body.should_not == response_3
    get '/route_arg_tag/tag1'
    last_response.body.should == response_1
  end
end