require 'test_helper'
require 'sunspot_matchers/test_helper'
require 'minitest/autorun'

class SearchControllerTest < ActionController::TestCase

  include SunspotMatchers::TestHelper
  include Test::Unit::Assertions

  fixtures :all

  def setup
    Sunspot.session = SunspotMatchers::SunspotSessionSpy.new(Sunspot.session)
  end

  test "should assign and match search param" do
    sources = Seek::Util.searchable_types
    sources.each do |src|
      Sunspot.search(src) do
        keywords 'compound'
      end
      assert_is_search_for Sunspot.session, src
      assert_has_search_params Sunspot.session, :keywords, 'compound'
    end
  end

  test "should not match search param keyword" do
    sources = Seek::Util.searchable_types
    sources.each do |src|
      Sunspot.search(src) do
        keywords 'compound identifier'
      end
      assert_has_no_search_params Sunspot.session, :keywords, 'pizza'
    end
  end
end
