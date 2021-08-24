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

  def session
    last_request.env["rack.session"]
  end

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def sign_in
    post "/users/signin", username: "admin", password: "secret"
  end

  def test_index
    sign_in
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
    sign_in
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
    sign_in
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

  def test_render_new_doc_form
    get "/new"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<form method='post' action='/'>"
  end

  def test_create_new_doc
    sign_in
    post '/', doc_title: "newdoc.txt"
    assert_equal 302, last_response.status
    
    # confirm new file is included in index listing
    get last_response["Location"]
    assert_includes last_response.body, "newdoc.txt"

    # confirm path to new file exists
    get '/newdoc.txt'
    assert_equal 200, last_response.status
  end

  def test_empty_doc_name
    filecount_before = get_files(data_path.size)
    post '/', doc_title: ""
    assert_equal 422, last_response.status

    # no Location is sent in response since the new template is rendered again rather than a redirect ocurring
    assert_includes last_response.body, "A name is required"

    # ensure no new file was created
    filecount_after = get_files(data_path.size)
    assert_equal filecount_before, filecount_after
  end

  def test_index_has_delete_buttons
    sign_in
    create_document "nub.md"

    get '/'
    assert_includes last_response.body, "<button type='submit'>Delete</button>"
  end
  
  def test_delete_document
    sign_in
    create_document "nub.md"

    post '/nub.md/delete'
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "nub.md was deleted."

    get "/"
    refute_includes last_response.body, "nub.md"
  end

  def test_not_signed_in
    get '/'
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "Username"
  end

  def test_bad_credentials
    post '/users/signin', username: "missy", password: "nub"
    assert_equal 422, last_response.status

    assert_includes last_response.body, "Invalid Credentials"
    assert_includes last_response.body, "Username"
  end

  def test_good_credentials
    create_document "nub.md"

    post '/users/signin', username: "admin", password: "secret"
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "Welcome!"
    assert_includes last_response.body, "nub.md"
    assert_includes last_response.body, "Signed in as admin."
  end

  def test_signout
    sign_in
    post 'users/signin', username: "admin", password: "secret"
    get last_response["Location"]
    assert_includes last_response.body, "Welcome"

    post '/users/signout'
    assert_equal 302, last_response.status
    get last_response["Location"]

    assert_includes last_response.body, "You have been signed out"
    assert_includes last_response.body, "Username"
  end

  def test_signout
    skip
    sign_in
    get last_response["Location"]
    assert_includes last_response.body, "Welcome"

    post "/users/signout"
    get last_response["Location"]

    assert_includes last_response.body, "You have been signed out"
    assert_includes last_response.body, "Sign In"
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end
end