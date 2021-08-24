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
    render_markdown(contents)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    contents
  end
end

get '/' do
  @files = get_files(data_path)
  erb :index
end

get '/:filename' do
  file_path = File.join(data_path, params[:filename])

  if File.file?(file_path)
    @content = load_contents(file_path)
    erb :file
  else
    session[:error] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

get '/:filename/edit_file' do
  file_path = File.join(data_path, params[:filename])
  @filename = params[:filename]
  @content = File.read(file_path)

  erb :edit_file
end

post '/:filename' do
  file_path = File.join(data_path, params[:filename])

  File.write(file_path, params[:content])
  session[:success] = "File has been edited."
  redirect "/#{params[:filename]}"
end