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
  file_path = current_dir + "/data/" + params[:filename]

  if File.file?(file_path)
    load_contents(file_path)
  else
    session[:error] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end