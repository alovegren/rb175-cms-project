require "sinatra"
require "sinatra/reloader"
require "sinatra/content_for"
require "tilt/erubis"

get '/' do
  @files = Dir.glob("/public/*").map { |file| File.basename(file) }
  erb :home
end