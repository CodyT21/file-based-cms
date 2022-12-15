require "sinatra"
require "sinatra/reloader"
require "sinatra/content_for"
require "tilt/erubis"
require 'redcarpet'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def load_file_content(file_path)
  content = File.read(file_path)
  case File.extname(file_path)
  when '.txt'
    headers['Content-Type'] = 'text/plain'
    content
  when '.md'
    erb render_markdown(content)
  end
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path('../test/data', __FILE__)
  else
    File.expand_path('../data', __FILE__)
  end
end

get '/' do
  pattern = File.join(data_path, '*')
  @files = Dir.glob(pattern).map { |file_path| File.basename(file_path) }

  erb :index
end

get '/new' do
  erb :new
end

post '/create' do
  new_filename = params[:new_filename].to_s

  if new_filename.size == 0
    session[:message] = "A name is required."
    status 422
    erb :new
  else
    new_file_path = File.join(data_path, new_filename)
  
    File.write(new_file_path, "")
    session[:message] = "#{new_filename} was successfully created."
    redirect '/'
  end
end

get '/:filename' do
  file_path = File.join(data_path, params[:filename])

  if File.file?(file_path)
    load_file_content(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist"
    redirect '/'
  end
end

post '/:filename' do
  file_path = File.join(data_path, params[:filename])

  File.write(file_path, params[:content])
  
  session[:message] = "#{params[:filename]} has been updated."
  redirect '/'
end

get '/:filename/edit' do
  file_path = File.join(data_path, params[:filename])

  if File.file?(file_path)
    @filename = params[:filename]
    @content = File.read(file_path)

    erb :edit
  else
    session[:message] = "#{params[:filename]} does not exist"
    redirect '/'
  end
end
