require 'sinatra'
require 'rack/ssl'
require 'librato-rack'

class Deploy
  attr_reader :source
  attr_reader :head
  attr_reader :user
  attr_reader :url

  def initialize(source, params)
    @source = source
    @head   = params.fetch('head_long')
    @user   = params.fetch('user')
    @url    = params.fetch('url')

    @time   = Time.now
  end

  def short_head
    head.slice(0,7)
  end

  def label
    "deployed v#{short_head}"
  end

  def description
    "#{user} deployed #{short_head} to #{source}"
  end

  def start_time
    @time.to_i
  end

  def end_time
    @time.to_i
  end

  def report!
    Librato::Metrics.annotate :deployments, label,
      source:      source,
      description: description,
      start_time:  start_time,
      end_time:    end_time,
      links: [
        {rel: 'app', href: url }
      ]
  end

end

# --

configure do
  STDOUT.sync = true
end

configure :production do
  use Rack::SSL
end

helpers do
  def protected!
    return if authorized?
    headers['WWW-Authenticate'] = 'Basic realm="Restricted Area"'
    halt(401, "Not authorized\n")
  end

  def authorized?
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? &&
      @auth.basic? &&
      @auth.credentials &&
      @auth.credentials == ENV['AUTH_BASIC'].split(':')
  end
end

get '/ping' do
  content_type :text
  'PONG'
end

post '/:source' do |source|
  protected!
  deploy = Deploy.new(source, params)
  deploy.report!
  content_type :text
  'ok'
end
