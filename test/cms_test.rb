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

  def admin_session
    { "rack.session" => { username: "admin" } }
  end

  def unauthorized_action_test
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_index
    create_document "about.md"
    create_document "changes.txt"

    get "/", {}, admin_session

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
    assert_equal "nub.rb does not exist.", session[:message]
  end

  def test_flash_after_edit
    skip
    post "/about.txt", content: "anything"

    assert_equal 302, last_response.status
    assert_equal "File has been edited.", session[:message]

    get "/", {}, admin_session
    assert_nil session[:message]
  end

  def test_edit_document
    post "/about.txt", { content: "THIS FILE HAS BEEN EDITED" }, admin_session
    # once the post request is fulfilled, user will be redirected
    assert_equal 302, last_response.status

    get "/about.txt"
    assert_includes last_response.body, "THIS FILE HAS BEEN EDITED"
  end

  def test_render_new_doc_form
    get "/new", {}, admin_session
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<form method='post' action='/'>"
  end

  def test_create_new_doc
    post '/create', { doc_title: "newdoc.txt" }, admin_session
    assert_equal 302, last_response.status
    assert_equal "newdoc.txt has been created", session[:message]
    
    # confirm new file is included in index listing
    get last_response["Location"]
    assert_includes last_response.body, "newdoc.txt"

    # confirm path to new file exists
    get '/newdoc.txt'
    assert_equal 200, last_response.status
  end

  def test_empty_doc_name
    filecount_before = get_files(data_path.size)
    post '/create', { doc_title: "" }, admin_session
    assert_equal 422, last_response.status

    # no Location is sent in response since the new template is rendered again rather than a redirect ocurring
    assert_includes last_response.body, "A name is required"

    # ensure no new file was created
    filecount_after = get_files(data_path.size)
    assert_equal filecount_before, filecount_after
  end

  def test_index_has_delete_buttons
    create_document "nub.md"

    get '/', {}, admin_session
    assert_includes last_response.body, "<button type='submit'>Delete</button>"
  end
  
  def test_delete_document
    create_document "nub.md"

    post '/nub.md/delete', {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "nub.md was deleted.", session[:message]

    get "/"
    refute_includes last_response.body, %q(href="/test.txt")
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
    assert_nil session[:username]
    assert_includes last_response.body, "Invalid Credentials"

  end

  def test_good_credentials
    post '/users/signin', username: "admin", password: "secret"
    assert_equal 302, last_response.status
    assert_equal "Welcome!", session[:message]
    assert_equal "admin", session[:username]
  end

  def test_signout
    get "/", {}, {"rack.session" => { username: "admin" } }
    assert_includes last_response.body, "Signed in as admin"

    post '/users/signout'
    assert_equal "You have been signed out", session[:message]

    get last_response["Location"]
    assert_nil session[:username]
    assert_includes last_response.body, "Username"
  end

  def test_signout
    skip
    get "/", {}, {"rack.session" => { username: "admin" } }
    assert_includes last_response.body, "Signed in as admin"

    post "/users/signout"
    assert_equal "You have been signed out", session[:message]
    
    get last_response["Location"]
    assert_nil session[:username]
    assert_includes last_response.body, "Sign In"
  end

  def test_unauthorized_edit
    create_document "nub.rb"

    get "/nub.rb/edit_file"
    unauthorized_action_test
  end

  def test_unauthorized_changes
    create_document "nub.rb"

    post "/nub.rb"
    unauthorized_action_test
  end

  def test_unauthorized_view_new_doc
    get "/new"
    unauthorized_action_test
  end

  def test_unauthorized_new_doc_submission
    post "/create"
    unauthorized_action_test
  end

  def test_unauthorized_doc_deletion
    create_document "nub.rb"

    post "nub.rb/delete"
    unauthorized_action_test
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end
end