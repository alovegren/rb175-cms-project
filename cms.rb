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
  @files = get_files(data_path)
  erb :index
end

# Render new doc form
get '/new' do
  erb :new
end

# Update filesystem with new document
post '/' do
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