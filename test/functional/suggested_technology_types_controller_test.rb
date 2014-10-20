require 'test_helper'

class SuggestedTechnologyTypesControllerTest < ActionController::TestCase

  include AuthenticatedTestHelper

  setup do
    login_as Factory(:user)
    @suggested_technology_type = Factory(:suggested_technology_type, :contributor_id => User.current_user.person.try(:id)).id
  end


  test "should not show manage page for normal user, but show for admins" do
    get :manage
    assert_redirected_to root_url
    logout
    login_as Factory(:user, :person_id => Factory(:admin).id)
    get :manage
    assert_response :success
  end


  test "should new" do
    get :new
    assert_response :success
  end

  test "should new with ajax" do
     xhr :get, "new"
     assert_response :success
  end

  test "should show edit own technology types" do
    get :edit, id: @suggested_technology_type
    assert_response :success
    assert_not_nil assigns(:suggested_technology_type)
  end

  test "should edit with ajax" do
     xhr :get, "edit", id: Factory(:suggested_technology_type, :contributor_id => User.current_user.person.try(:id)).id
     assert_response :success
   end


  test "should create" do
    login_as Factory(:admin)
    assert_difference("SuggestedTechnologyType.count") do
      post :create, :suggested_technology_type => {:label => "test technology type"}
    end
    assert_redirected_to :action => :manage
    get :manage
    assert_select "li a", :text => /test technology type/
  end

  test "should create for ajax request" do
     assert_difference("SuggestedTechnologyType.count") do
       xhr :post,  :create, :suggested_technology_type => {:label => "test_technology_type"}
     end
     assert_select "select option[selected='selected']",  :text=>/test_technology_type/
   end

  test "should update for ajax request" do
     suggested_technology_type = Factory(:suggested_technology_type, :contributor_id => User.current_user.person.try(:id))
     xhr :put,  :update,  id: suggested_technology_type.id, suggested_technology_type: {:label => "child_technology_type_a"}
     assert_select "select option[value=?][selected='selected']",suggested_technology_type.uri, :text=>/child_technology_type_a/
  end

  test "should update label" do
    login_as Factory(:admin)
    put :update, id: @suggested_technology_type, suggested_technology_type: {:label => "new label"}
    assert_redirected_to :action => :manage
    get :manage
    suggested_technology_type = SuggestedTechnologyType.find @suggested_technology_type
    assert_select "li a[href=?]", ERB::Util.html_escape(technology_types_path(uri: suggested_technology_type.uri, label: "new label")), :text => /new label/
  end

  test "should update parent" do
    login_as Factory(:admin)
    suggested_parent1 = Factory(:suggested_technology_type)
    suggested_parent2 = Factory(:suggested_technology_type)
    ontology_parent_uri = "http://www.mygrid.org.uk/ontology/JERMOntology#Gas_chromatography"
    ontology_parent = Factory(:suggested_technology_type).class.base_ontology_hash_by_uri[ontology_parent_uri]
    suggested_technology_type = Factory(:suggested_technology_type, :contributor_id => User.current_user.person.try(:id), :parent_uri => suggested_parent1.uri)
    assert_equal 1, suggested_technology_type.parents.size
    assert_equal suggested_parent1, suggested_technology_type.parents.first
    assert_equal suggested_parent1.uri, suggested_technology_type.parent.uri.to_s

    #update to other parent suggested
    put :update, :id => suggested_technology_type.id, :suggested_technology_type => {:parent_uri => suggested_parent2.uri}
    assert_redirected_to :action => :manage

    #update to other parent from ontology
    put :update, id: suggested_technology_type.id, suggested_technology_type: {:parent_uri => ontology_parent_uri}
    assert_redirected_to :action => :manage

  end

  test "should delete suggested technology type" do
    #even owner cannot delete own type
    assert_no_difference('SuggestedTechnologyType.count') do
      delete :destroy, id: @suggested_technology_type
    end
    assert_equal "Admin rights required to manage types", flash[:error]
    flash[:error] = nil
    logout
    #log in as another user, who is not the owner of the suggested technology type
    login_as Factory(:user)
    assert_no_difference('SuggestedTechnologyType.count') do
      delete :destroy, id: @suggested_technology_type
    end

    assert_equal "Admin rights required to manage types", flash[:error]
    flash[:error] = nil
    logout

    #log in as admin
    login_as Factory(:user, :person_id => Factory(:admin).id)
    assert_difference('SuggestedTechnologyType.count', -1) do
      delete :destroy, id: @suggested_technology_type
    end
    assert_nil flash[:error]
    assert_redirected_to :action => :manage
  end

  test "should not delete technology type with child" do
    login_as Factory(:user, :person_id => Factory(:admin).id)

    parent = Factory :suggested_technology_type
    child = Factory :suggested_technology_type, :parent_uri => parent.uri

    assert_no_difference('SuggestedTechnologyType.count') do
      delete :destroy, id: parent.id
    end
    assert flash[:error]
    assert_redirected_to :action => :manage
  end

  test "should not delete technology type with assays" do
    login_as Factory(:user, :person_id => Factory(:admin).id)

    suggested = Factory :suggested_technology_type
    Factory(:experimental_assay, :technology_type_uri => suggested.uri)
    assert_no_difference('SuggestedTechnologyType.count') do
      delete :destroy, id: suggested.id
    end
    assert flash[:error]
    assert_redirected_to :action => :manage
  end

end
