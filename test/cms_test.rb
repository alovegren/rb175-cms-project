ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "minitest/reporters"
require "pry"

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
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "Our understanding of what Gogol meant"
  end

  def test_nonexistent_file
    get "/nub.rb"

    assert_equal 302, last_response.status

    get last_response["Location"]

    assert_equal 200, last_response.status
    assert_includes last_response.body, "nub.rb does not exist."

    get "/"
    refute_includes last_response.body, "nub.rb does not exist."
  end

  # test/cms_test.rb
  def test_viewing_markdown_document
    get "/nub.md"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Nub</h1>"
  end

  def test_flash_after_edit
    post "/about.txt", content: "THIS FILE HAS BEEN EDITED........ but it used to say a whole lot of cool stuff about Gogol :-( I didn't realize my tests would alter the file!"

    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "File has been edited."

    get "/"
    refute_includes last_response.body, "File has been edited."
  end

  def test_edit_document
    post "/about.txt", content: "THIS FILE HAS BEEN EDITED"
    # once the post request is fulfilled, user will be redirected
    assert_equal 302, last_response.status

    get "/about.txt"
    assert_includes last_response.body, "THIS FILE HAS BEEN EDITED"
  end
end