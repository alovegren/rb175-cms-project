require "sinatra"
require "sinatra/reloader"
require "sinatra/content_for"
require "tilt/erubis"

get '/' do
  current_dir = File.expand_path("..", __FILE__)
  @files = Dir.glob("#{current_dir}/data/*").map { |file| File.basename(file) }
  erb :home
end