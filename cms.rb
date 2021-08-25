require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "redcarpet"
require "yaml"
require "bcrypt"

SUPPORTED_EXTENSIONS = ['.md', '.txt', '.html']

configure do
  enable :sessions
  set :session_secret, 'secret'
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def credentials_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yaml", __FILE__)
  else
    File.expand_path("../users.yaml", __FILE__)
  end
end

def get_files(data_path)
  Dir.glob("#{data_path}/*").map { |file| File.basename(file) }
end

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def load_contents(file_path)
  contents = File.read(file_path)

  case File.extname(file_path)
  when ".md"
    erb render_markdown(contents)
  else
    headers["Content-Type"] = "text/plain"
    contents
  end
end

def unauthorized_action_redirect
  session[:message] = "You must be signed in to do that."
  redirect "/"
end

def get_valid_users
  YAML.load_file(credentials_path)
end

def valid_login?(username, password)
  valid_users = get_valid_users

  valid_users.key?(username) &&
  BCrypt::Password.new(valid_users[username]) == password
end

# View all files
get '/' do
  if session[:username]
    @files = get_files(data_path)
    erb :index
  else
    redirect '/users/signin'
  end
end

# Render new doc form
get '/new' do
  if session[:username]
    erb :new
  else
    unauthorized_action_redirect
  end
end

# Update filesystem with new document
post '/create' do
  if session[:username]
    docname = params[:doc_title]
    if docname.empty?
      session[:message] = "A name is required"
      status 422
      erb :new
    elsif SUPPORTED_EXTENSIONS.none? { |ext| docname.include? ext }
      session[:message] = "Sorry, only .md, .txt, and .html are supported. Please enter a file name with a supported extension."
      status 422
      erb :new
    else
      File.write("#{data_path}/#{docname}", "")
      session[:message] = "#{docname} has been created"
      redirect "/"
    end
  else
    unauthorized_action_redirect
  end
end

# View file
get '/:filename' do 
  file_path = File.join(data_path, params[:filename])

  if File.file?(file_path)
    load_contents(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

# Render edit form
get '/:filename/edit_file' do
  if session[:username]
    file_path = File.join(data_path, params[:filename])
    @filename = params[:filename]
    @content = File.read(file_path)

    erb :edit_file
  else
    unauthorized_action_redirect
  end
end

# Update filesystem with document edit form
post '/:filename' do
  if session[:username]
    file_path = File.join(data_path, params[:filename])

    File.write(file_path, params[:content])
    session[:message] = "File has been edited."
    redirect "/"
  else
    unauthorized_action_redirect
  end
end

# delete a file
post '/:filename/delete' do
  if session[:username]
    file_path = File.join(data_path, params[:filename])

    File.delete(file_path)

    session[:message] = "#{params[:filename]} was deleted."
    redirect "/"
  else
    unauthorized_action_redirect
  end
end

# render sign up form
get '/users/signup' do
  erb :signup
end

# post username and hashed password to server
post '/users/signup' do
  password = BCrypt::Password.create(params[:password])
  new_user_entry = "\n#{params[:username]}: #{password}"

  File.write(credentials_path, new_user_entry, mode: "a")
  session[:message] = "Thank you for creating an account. Please sign in."
  redirect '/users/signin'
end

# render sign in form
get '/users/signin' do
  erb :signin
end

# update session data with login info
post '/users/signin' do
  if valid_login?(params[:username], params[:password])
    session[:username] = params[:username]
    session[:message] = "Welcome!"
    redirect "/"
  else
    session[:message] = "Invalid Credentials"
    status 422
    erb :signin
  end
end

# sign a user out
post '/users/signout' do
  session.delete(:username)
  session[:message] = "You have been signed out"
  redirect "/"
end