require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/content_for'
require 'tilt/erubis'
require 'redcarpet'
require 'yaml'
require 'bcrypt'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

def load_user_credentials
  users_path = if ENV['RACK_ENV'] == 'test'
                 File.expand_path('../test/users', __FILE__)
               else
                 File.expand_path('../users', __FILE__)
               end
  
  YAML.load_file(File.join(users_path, 'users.yml'))
end

def valid_credentials?(user_id, password)
  credentials = load_user_credentials

  if credentials.key?(user_id)
    bcrypt_password = BCrypt::Password.new(credentials[user_id])
    bcrypt_password == password
  else
    false
  end
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
  if ENV['RACK_ENV'] == 'test'
    File.expand_path('../test/data', __FILE__)
  else
    File.expand_path('../data', __FILE__)
  end
end

def user_signed_in?
  session.key?(:user_id)
end

def require_user_signin
  unless user_signed_in?
    session[:message] = 'You must be signed in to perform that action.'
    redirect '/'
  end
end

# Render index page
get '/' do
  pattern = File.join(data_path, '*')
  @files = Dir.glob(pattern).map { |file_path| File.basename(file_path) }

  erb :index
end

# Render new document page
get '/new' do
  require_user_signin
  erb :new
end

# Create a new document
post '/create' do
  require_user_signin

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

# Render signin page
get '/users/signin' do
  if !session[:user_id]
    erb :login
  else
    redirect '/'
  end
end

# Sign user into site
post '/users/signin' do
  credentials = load_user_credentials
  user_id = params[:user_id]
  password = params[:password]

  if valid_credentials?(user_id, password)
    session[:user_id] = params[:user_id]
    session[:message] = 'Welcome!'
    redirect '/'
  else
    session[:message] = 'Invalid credentials.'
    status 422
    erb :login
  end
end

# Sign out user
post '/users/signout' do
  session.delete(:user_id)
  session[:message] = "You have been signed out."
  redirect '/'
end

# Display a file
get '/:filename' do
  file_path = File.join(data_path, params[:filename])

  if File.file?(file_path)
    load_file_content(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect '/'
  end
end

# Edit a file
post '/:filename' do
  require_user_signin

  file_path = File.join(data_path, params[:filename])

  File.write(file_path, params[:content])
  
  session[:message] = "#{params[:filename]} has been updated."
  redirect '/'
end

# Render file edit page
get '/:filename/edit' do
  require_user_signin
    
  file_path = File.join(data_path, params[:filename])

  if File.file?(file_path)
    @filename = params[:filename]
    @content = File.read(file_path)

    erb :edit
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect '/'
  end
end

# Delete a document
post '/:filename/delete' do
  require_user_signin

  file_path = File.join(data_path, params[:filename])
  File.delete(file_path)

  session[:message] = "#{params[:filename]} has been deleted."
  redirect '/'
end
