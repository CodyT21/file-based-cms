ENV['RACK_ENV'] = 'test'

require 'fileutils'
require 'minitest/autorun'
require 'rack/test'

require_relative '../cms'

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def create_document(name, content='')
    File.open(File.join(data_path, name), 'w') do |file|
      file.write(content)
    end
  end

  def session
    last_request.env['rack.session']
  end

  def admin_session
    { 'rack.session' => { user_id: 'admin' } }
  end

  def app
    Sinatra::Application
  end

  def test_index
    create_document 'about.md'
    create_document 'changes.txt'

    get '/'
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, 'about.md'
    assert_includes last_response.body, 'changes.txt'
  end

  def test_about
    create_document 'history.txt', '2015 - Ruby 2.3 released.'

    get '/history.txt'
    assert_equal 200, last_response.status
    assert_equal 'text/plain', last_response['Content-Type']
    assert_includes last_response.body, '2015 - Ruby 2.3 released.'
  end

  def test_document_not_found
    get '/notafile.ext'
    assert_equal 302, last_response.status
    assert_equal 'notafile.ext does not exist.', session[:message]
  end

  def test_render_markdown
    create_document 'about.md', '# Ruby is...'

    get '/about.md'
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response['Content-Type']
    assert_includes last_response.body, '<h1>Ruby is...</h1>'
  end
  
  def test_edit_document
    create_document 'changes.txt', 'document content'

    get '/changes.txt/edit', {}, admin_session
    assert_equal 200, last_response.status
    assert_includes last_response.body, '<textarea'
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_edit_document_signed_out
    create_document 'changes.txt', 'document content'

    get '/changes.txt/edit'
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to perform that action.', session[:message]
  end
    

  def test_updating_document
    create_document 'changes.txt', 'document content'

    post '/changes.txt', {content: 'new text'}, admin_session
    assert_equal 302, last_response.status
    assert_equal 'changes.txt has been updated.', session[:message]
    
    get '/changes.txt'
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'new text'
  end

  def test_updating_document_signed_out
    post '/changes.txt', {content: 'new text'}
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to perform that action.', session[:message]
  end

  def test_new_document_form
    get '/new', {}, admin_session
    assert_equal 200, last_response.status
    assert_includes last_response.body, '<input'
    assert_includes last_response.body, %q(<input type="submit")
  end

  def test_new_document_form_signed_out
    get '/new'
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to perform that action.', session[:message]
  end

  def test_create_new_document
    post '/create', {new_filename: 'new_doc.txt'}, admin_session
    assert_equal 302, last_response.status
    assert_equal 'new_doc.txt was successfully created.', session[:message]

    get '/'
    assert_includes last_response.body, 'new_doc.txt'
  end

  def test_create_new_document_signed_out
    post '/create', {new_filename: 'new_doc.txt'}
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to perform that action.', session[:message]
  end

  def test_create_new_document_no_filename
    post '/create', {new_filename: ''}, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'A name is required.'
  end

  def test_delete_document
    create_document 'new_doc.txt'

    post 'new_doc.txt/delete', {}, admin_session
    assert_equal 302, last_response.status
    assert_equal 'new_doc.txt has been deleted.', session[:message]

    get '/'
    refute_includes last_response.body, %q(href="/new_doc.txt")
  end

  def test_delete_document_signed_out
    create_document 'new_doc.txt'

    post 'new_doc.txt/delete'
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to perform that action.', session[:message]
  end

  def test_signin_form
    get '/users/signin'
    assert_equal 200, last_response.status
    assert_includes last_response.body, '<input'
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_signin
    post '/users/signin', user_id: 'admin', password: 'secret'
    assert_equal 302, last_response.status
    assert_equal 'Welcome!', session[:message]
    assert_equal 'admin', session[:user_id]

    get last_response['Location']
    assert_includes last_response.body, 'Signed in as admin'
  end

  def test_invalid_signin
    post '/users/signin', user_id: 'admin', password: ''
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Invalid credentials'
  end

  def test_signout
    get '/', {}, admin_session
    assert_includes last_response.body, 'Signed in as admin'

    post '/users/signout'
    assert_equal 'You have been signed out.', session[:message]

    get last_response['Location']
    assert_nil session[:user_id]
    assert_includes last_response.body, 'Sign In'
  end
end