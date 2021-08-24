require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "redcarpet"

configure do
  enable :sessions
  set :session_secret, 'secret'
end

current_dir = File.expand_path("..", __FILE__)

def get_abs_filepath(current_dir)
  Dir.glob("#{current_dir}/data/*").map { |file| File.basename(file) }
end

def get_filepath(current_dir)
  current_dir + "/data/" + params[:filename]
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
  @files = get_abs_filepath(current_dir)
  erb :index
end

get '/:filename' do
  @file_path = (get_filepath(current_dir))

  if File.file?(@file_path)
    @content = load_contents(@file_path)
    erb :file
  else
    session[:error] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

get '/:filename/edit_file' do
  @filename = params[:filename]
  @content = File.read((get_filepath(current_dir)))

  erb :edit_file
end

post '/:filename' do
  filename = params[:filename]
  file_path = get_filepath(current_dir)
  new_contents = params[:content]

  File.write(file_path, new_contents)
  session[:success] = "File has been edited."
  redirect "/#{filename}"
end