require 'sinatra/base'
require 'sinatra/assetpack'
require 'sinatra/support'
require 'compass'
require 'addressable/uri'
require 'json'
require 'net/https'
require 'elasticsearch'
require 'loofah'

class Aoi < Sinatra::Base

  configure do
    data = open('config.json') do |io|
      JSON.load(io)
    end
    use Rack::Session::Cookie, :secret => data['session_secret']
    set :client_id, data['client_id']
    set :client_secret, data['client_secret']
    set :project_name, data['project_name'] || ''
    set :index, data['index'] || 'aoi'
    set :members, data['members'] || []
  end
  
  register Sinatra::CompassSupport
  compass = Compass.configuration
  compass.project_path = root
  compass.images_dir = "public/images"
  compass.http_generated_images_path = "/images"

  register Sinatra::AssetPack
  assets do
    serve '/assets/js', :from => 'assets/js'
    serve '/assets/css', :from => 'assets/scss'
    js :application, [
         '/assets/js/jquery.js',
         '/assets/js/marked.js',
         '/assets/js/app.js'
    ]
    css :application, [
          '/assets/css/github-markdown.css',
          '/assets/css/app.css'
    ]
    js_compression :jsmin
    css_compression :sass
  end

  def es
    Elasticsearch::Client.new log: false
  end

  helpers do
    def project_name
      settings.project_name
    end
  end
  helpers do
    def strip_script(html)
      doc = Loofah.fragment(html).scrub!(:prune)
      doc.to_s
    end
  end
  helpers do
    include Rack::Utils
    alias_method :h, :escape_html
  end
  
  before do
    pass if request.path_info =~ /(?:^\/login|^\/assets|^\/callback)/
    redirect to('/login') unless !session[:user].nil?
  end
  
  get '/' do
    redirect to('/entry')
  end

  get '/write' do
    erb :write
  end

  post '/write' do
    body = { title: params['title'], content: params['content'], user: session[:user], time: Time.now.to_i }
    response = es.index index: settings.index, type: 'entry', body: body
    es.indices.refresh index: settings.index
    id = response['_id']
    redirect to ("/entry/#{id}")
  end

  get '/search' do
    query = params['q']
    redirect to('/entry') if query.empty?
    body = { query: { simple_query_string: { fields: ["content", "title"], query: query } } }
    response = es.search index: settings.index, type: 'entry', body: body
    total = response['hits']['total']
    sources = response['hits']['hits']
    erb :search, :locals => { :total => total, :sources => sources, :query => query }
  end
  
  get '/entry' do
    size = 20
    page = params['page'] || 1;
    from = (page.to_i - 1) * 3
    body = { size: size, from: from, sort: [ { time: 'desc' } ], query: { match_all:{} } }
    begin response = es.search index: settings.index, type: 'entry', body: body
    rescue Elasticsearch::Transport::Transport::Errors::NotFound
      erb :entries, :locals => { :total => 0, :sources => [], :size => size, :page => page }
    end
    total = !response.nil? ? response['hits']['total'] : 0
    if from >= total.to_i 
      erb :entries, :locals => { :total => 0, :sources => [], :size => size, :page => page }
    end
    sources = !response.nil? ? response['hits']['hits'] : []
    erb :entries, :locals => { :total => total, :sources => sources, :size => size, :page => page }
  end
  
  get '/entry/:id' do
    id = params['id']
    entry = es.get index: settings.index, type: 'entry', id: id
    erb :show, :locals => { :entry => entry }
  end

  get '/entry/:id/?edit' do
    id = params['id']
    entry = es.get index: settings.index, type: 'entry', id: id
    redirect to('/') unless entry['_source']['user']['id'] == session[:user][:id]
    erb :edit, :locals => { :entry => entry }
  end
  
  post '/entry/:id/?edit' do
    id = params['id']
    entry = es.get index: settings.index, type: 'entry', id: id
    redirect to('/') unless entry['_source']['user']['id'] == session[:user][:id]
    body = { doc: { title: params['title'], content: params['content'],
                    user: session[:user], time: entry['_source']['time'] || Time.now.to_i } }
    response = es.update index: settings.index, type: 'entry', id: id, body: body
    redirect to ("/entry/#{id}")
  end

  get '/entry/:id/?delete' do
    id = params['id']
    entry = es.get index: settings.index, type: 'entry', id: id
    redirect to('/') unless entry['_source']['user']['id'] == session[:user][:id]
    es.delete index: settings.index, type: 'entry', id: id
    redirect to('/');
  end
  
  get '/login' do
    erb :login, :layout => false
  end

  post '/login' do
    uri = Addressable::URI.parse('https://github.com/login/oauth/authorize')
    uri.query_values = {
      :client_id => settings.client_id,
      :redirect_url => "#{env['rack.url_scheme']}://#{env['HTTP_HOST']}/callback"
    }
    redirect uri
  end

  get '/callback' do
    code = params['code']
    redirect to('/login') if code.to_s.empty?
    auth_uri = Addressable::URI.parse('https://github.com/login/oauth/access_token')
    auth_uri.query_values = {
      :client_id => settings.client_id,
      :client_secret => settings.client_secret,
      :code => code
    }
    http = Net::HTTP.new('github.com', 443)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    
    request = Net::HTTP::Get.new(auth_uri.normalize.request_uri)
    request['Accept'] = 'application/json'
    response = http.request(request)
    access_token = JSON.parse(response.body)["access_token"]

    user_uri = Addressable::URI.parse('https://api.github.com/user')
    user_uri.query_values = {
      :client_id => settings.client_id,
      :client_secret => settings.client_secret,
      :access_token => access_token
    }
    http = Net::HTTP.new('api.github.com', 443)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    response = http.get(user_uri.normalize.request_uri)
    user_info = JSON.parse(response.body)
    members = settings.members.grep(user_info['login'])
    redirect to('/login') unless members.length > 0
    session[:user] = {
      :id => user_info['id'],
      :login => user_info['login'],
      :avatar_url => user_info['avatar_url']
    }
    redirect to('/')
  end

  get '/logout' do
    session.clear
    redirect '/login'
  end

  not_found do
    "The content is not found..."
  end
end

