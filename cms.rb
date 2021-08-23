require "sinatra"
require "sinatra/reloader"
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'secret'
end

helpers do
  def get_current_dir
    File.expand_path("..", __FILE__)
  end

  def get_abs_filepath
    current_dir = get_current_dir
    Dir.glob("#{current_dir}/data/*").map { |file| File.basename(file) }
  end
end

get '/' do
  @files = get_abs_filepath
  erb :home
end

get '/:filename' do
  file_path = get_current_dir + "/data/" + params[:filename]

  if File.file?(file_path)
    headers["Content-Type"] = "text/plain"
    File.read(file_path)
  else
    session[:error] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end