ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"

require_relative "../cms"

class AppTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_index
    get '/'
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, 'changes.txt'
    assert_includes last_response.body, 'history.txt'
    assert_includes last_response.body, 'about.txt'
  end

  def test_about
    get '/about.txt'
    assert_equal 200, last_response.status
    assert_equal 'text/plain', last_response['Content-Type']
    assert_includes last_response.body, '2015 - Ruby 2.3 released.'
  end

  def test_document_not_found
    get '/notafile.ext'
    assert_equal 302, last_response.status
    
    get last_response['Location']
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, 'notafile.ext does not exist'
    
    get '/'
    refute_includes last_response.body, 'notafile.ext does not exist'
  end

  def test_render_markdown
    get '/about.md'
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response['Content-Type']
    assert_includes last_response.body, '<h1>Ruby is...</h1>'
  end 
end