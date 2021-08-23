ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "minitest/reporters"

Minitest::Reporters.use!

require_relative "../cms"

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    @current_dir = File.expand_path("..", __FILE__)
    @files = Dir.glob("#{@current_dir}/data/*").map { |file| File.basename(file) }
  end

  def test_index
    get "/"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert @files.all? { |file| last_response.body.include?(file) }
  end

  def test_view_file
    get "/history.txt"
    filename = "#{@current_dir}/../data/history.txt"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_equal File.read(filename), last_response.body
  end
end