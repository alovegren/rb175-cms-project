require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "redcarpet"

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
  erb :new
end

# Update filesystem with new document
post '/create' do
  docname = params[:doc_title]
  if docname.empty?
    session[:message] = "A name is required"
    status 422
    erb :new
  else
    File.write("#{data_path}/#{docname}", "")
    session[:message] = "#{docname} has been created"
    redirect "/"
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
  file_path = File.join(data_path, params[:filename])
  @filename = params[:filename]
  @content = File.read(file_path)

  erb :edit_file
end

# Update filesystem with document edit form
post '/:filename' do
  file_path = File.join(data_path, params[:filename])

  File.write(file_path, params[:content])
  session[:message] = "File has been edited."
  redirect "/"
end

# delete a file
post '/:filename/delete' do
  file_path = File.join(data_path, params[:filename])

  File.delete(file_path)

  session[:message] = "#{params[:filename]} was deleted."
  redirect "/"
end

# render sign in form
get '/users/signin' do
  erb :signin
end

# update session data with login info
post '/users/signin' do
  if params[:username] == "admin" && params[:password] == "secret"
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

=begin
+ on home page, check whether a user is signed in via a session parameter
  + if not, redirect to users/signin
  + if so, proceed with existing code in '/' route
+ create new route for users/signin
+ within the route, display a signin form
  + if credentials match, 
    + direct signin to a post route
  + otherwise,
    + display an error message and re-render the signin form
+ create post route to update the server with the signin information
+ set session parameter corresponding to login equal to true
+ redirect to homepage

+ add 'signed in as $USER' to home page
+ add signout button
  + post button output to some signout route
  - set login equal to false
  - redirect to homepage
=end