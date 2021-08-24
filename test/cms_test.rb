ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "minitest/reporters"
require "pry"
require "fileutils"

Minitest::Reporters.use!

require_relative "../cms"

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def test_index
    create_document "about.md"
    create_document "changes.txt"

    get "/"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
  end

  def test_view_text_file
    create_document "changes.txt", "Emmers was a fine gentleman whose house was made of clay."

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "Emmers was a fine gentleman"
  end

  def test_view_markdown_file
    create_document "nub.md", "# Nub"
    get "/nub.md"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Nub</h1>"
  end

  def test_nonexistent_file
    get "/nub.rb"

    assert_equal 302, last_response.status

    get last_response["Location"]

    assert_equal 200, last_response.status
    assert_includes last_response.body, "nub.rb does not exist."

    # ensure flash error is displaying and being deleted properly
    get "/"
    refute_includes last_response.body, "nub.rb does not exist."
  end

  def test_flash_after_edit
    post "/about.txt", content: "anything"

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

  def teardown
    FileUtils.rm_rf(data_path)
  end
end