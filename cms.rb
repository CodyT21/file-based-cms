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
    render_markdown(content)
  end
end

root = File.expand_path('..', __FILE__)

get '/' do
  @files = Dir.glob(root + '/data/*').map { |file_path| File.basename(file_path) }

  erb :index
end

get '/:filename' do
  file_path = root + '/data/' + params[:filename]

  if File.file?(file_path)
    load_file_content(file_path)
  else
    session[:error] = "#{params[:filename]} does not exist"
    redirect '/'
  end
end

post '/:filename' do
  file_path = root + '/data/' + params[:filename]

  File.write(file_path, params[:content])
  
  session[:success] = "#{params[:filename]} has been updated."
  redirect '/'
end

get '/:filename/edit' do
  file_path = root + '/data/' + params[:filename]

  if File.file?(file_path)
    @filename = params[:filename]
    @content = File.read(file_path)

    erb :edit
  else
    session[:error] = "#{params[:filename]} does not exist"
    redirect '/'
  end
end