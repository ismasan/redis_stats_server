require 'rubygems'
require 'bundler'
Bundler.setup :default, :tracker

require 'eventmachine'
require 'evma_httpserver'
require 'rack'
require 'json'
require 'em-hiredis'
require File.join(File.dirname(__FILE__), 'mapper')


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
    
    @params = Rack::Utils.parse_nested_query(@http_query_string)

    @response = EM::DelegatedHttpResponse.new(self)
    
    # Router
    case @http_path_info
    when /\/track\.gif/
      handle_hit
    when /^\/r/
      serve_graph
    else
      not_found
    end
    
  end
  
  protected
  
  TIME_KEYS = [:year, :month, :day, :min]
  
  def handle_hit
    # /track.gif?y=2011&mm=09&d=30&t=11&m=54&h=foo.com&p=/home&e=new_user
    #
    # a       account_key
    # y       year
    # mm      month
    # t       hour
    # m       minute
    # h       host
    # 
    # Store UTC time, compare with client-provided tz (timezone offset)
    now = Time.now.getutc
    
    # sadd 'y:2011', 'some_uid'
    # sadd 'm:10', 'some_uid' 
    TIME_KEYS.each do |period|
      REDIS.sadd("#{period}:#{now.send(period)}", unique_hit_id)
    end
    p [:track, @params]
    # Store unique id in all passed params with prefixes
    @params.each do |prefix, val| # y, 2011 | m, 03
      p [:foo, prefix, val]
      REDIS.sadd("#{prefix}:#{val}", unique_hit_id) unless TIME_KEYS.include?(prefix.to_sym)
    end
    
    # That's it! Don't even wait for redis responses
    @response.content_type 'image/gif'
    @response.status = 200
    @response.headers['Cache-Control'] = 'no-store, no-cache, must-revalidate, private' # browsers should not cache this
    @response.headers['Pragma'] = 'no-cache'
    @response.headers['Expires'] = 'no-cache'
    @response.content = 'Fri, 24 Nov 2000 01:00:00 GMT'
    @response.send_response
  end
  
  def serve_graph
    columns   = @params['columns'] ? @params['columns'].split(',') : []
    rows      = @params['rows'] ? @params['rows'].split(',') : []
    filters   = @params['filters'] ? @params['filters'].split(',') : []
    
    Mapper.new(:columns => columns, :rows => rows, :filters => filters) do |data|
      @response.content_type 'application/json'
      @response.status = 200
      @response.content = JSON.unparse(data)
      @response.send_response
    end
    
  end
  
  def not_found
    @response.content_type 'image/gif'
    @response.status = 404
    @response.content = ''
    @response.send_response
  end
  
  def remote_ip
    @remote_ip ||= (
      @http_headers =~ /X-Forwarded-For: (\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/
      $1
    )
  end
  
  def unique_hit_id
    @unique_hit_id ||= [remote_ip, (Time.now.to_f * 1000).to_i].join(':')
  end

end

EM.run{
  REDIS = EM::Hiredis.connect
  EM.start_server '0.0.0.0', ENV['PORT'], Api
}