require 'rubygems'
require 'bundler'
Bundler.setup :default, :tracker

require 'eventmachine'
require 'evma_httpserver'
require 'rack'

require 'em-hiredis'


class Api < EM::Connection
  include EM::HttpServer

   def post_init
     super
     no_environment_strings
   end

  def process_http_request
    # the http request details are available via the following instance variables:
    #   @http_protocol
    #   @http_request_method
    #   @http_cookie
    #   @http_if_none_match
    #   @http_content_type
    #   @http_path_info
    #   @http_request_uri
    #   @http_query_string
    #   @http_post_content
    #   @http_headers
    
    params = Rack::Utils.parse_nested_query(@http_query_string)
    response = EM::DelegatedHttpResponse.new(self)
    response.content_type 'image/gif'
    
    # /:hit_key/_utm.gif?y=2011&mm=09&d=30&t=11&m=54&h=foo.com&p=/home&e=new_user
    #
    # a       account_key
    # y       year
    # mm      month
    # t       hour
    # m       minute
    # h       host
    # 
    hit_key = @http_path_info.split('/').reject{|s| s==''}.first
    
    # Store session id in all passed params with prefixes
    params.each do |prefix, val| # y, 2011 | m, 03
      REDIS.sadd("#{prefix}:#{val}", hit_key)
    end
    
    # That's it! Don't even wait for redis responses
    response.status = 200
    response.headers['Cache-Control'] = 'no-cache' # browsers should not cache this
    response.content = ''
    response.send_response
  end

end

EM.run{
  REDIS = EM::Hiredis.connect
  EM.start_server '0.0.0.0', ENV['PORT'], Api
}