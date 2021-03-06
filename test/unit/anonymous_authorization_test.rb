require 'test_helper'
#Authorization tests that are specific to public access
class AnonymousAuthorizationTest < ActiveSupport::TestCase

  def test_anonymous
    fully_public_policy = Factory(:policy,:sharing_scope=>Policy::EVERYONE,:access_type=>Policy::EDITING)
    sop = Factory :sop,:policy=> fully_public_policy
    assert_equal Policy::EVERYONE,sop.policy.sharing_scope
    assert_equal Policy::EDITING,sop.policy.access_type

    assert Seek::Permissions::Authorization.is_authorized? "view",nil,sop,nil
    assert Seek::Permissions::Authorization.is_authorized? "edit",nil,sop,nil
    assert Seek::Permissions::Authorization.is_authorized? "download",nil,sop,nil
    assert !Seek::Permissions::Authorization.is_authorized?("manage",nil,sop,nil)

    assert sop.can_view?
    assert sop.can_edit?
    assert sop.can_download?
    assert !sop.can_manage?
  end

  test "anonymous cannot view access or edit non public sop" do
    sop=Factory :sop,:policy=>Factory(:all_sysmo_downloadable_policy)

    assert_equal Policy::ALL_SYSMO_USERS,sop.policy.sharing_scope
    assert_equal Policy::ACCESSIBLE,sop.policy.access_type

    assert !Seek::Permissions::Authorization.is_authorized?("view",nil,sop,nil)
    assert !Seek::Permissions::Authorization.is_authorized?("edit",nil,sop,nil)
    assert !Seek::Permissions::Authorization.is_authorized?("download",nil,sop,nil)
    assert !Seek::Permissions::Authorization.is_authorized?("manage",nil,sop,nil)

    assert !sop.can_view?
    assert !sop.can_edit?
    assert !sop.can_download?
    assert !sop.can_manage?
  end

  test "anonymous can view but not edit or access publically viewable sop" do
    User.current_user = nil
    sop = Factory :sop, :policy => Factory(:policy, :sharing_scope => Policy::EVERYONE, :access_type => Policy::VISIBLE)

    assert sop.can_view?
    assert !sop.can_edit?
    assert !sop.can_download?
    assert !sop.can_manage?
  end

  test "anonymous can view and download but not edit publically viewable sop" do
    User.current_user = nil
    sop=Factory :sop, :policy => Factory(:policy, :sharing_scope => Policy::EVERYONE, :access_type => Policy::ACCESSIBLE)

    assert sop.can_view?
    assert sop.can_download?
    assert !sop.can_edit?
    assert !sop.can_manage?
  end



  test "anonymous user allowed to perform an action" do
    # it doesn't matter for this test case if any permissions exist for the policy -
    # these can't affect anonymous user; hence can only check the final result of authorization
    fully_public_policy = Factory(:policy,:sharing_scope=>Policy::EVERYONE,:access_type=>Policy::EDITING)
    sop=  Factory :sop,:policy=>fully_public_policy
    # verify that the policy really provides access to anonymous users
    temp = sop.policy.sharing_scope
    temp2 = sop.policy.access_type
    assert temp == Policy::EVERYONE && temp2 > Policy::NO_ACCESS, "policy should provide some access for anonymous users for this test"

    res = Seek::Permissions::Authorization.is_authorized?("edit", nil, sop, nil)
    assert res, "anonymous user should have been allowed to 'edit' the SOP - it uses fully public policy"
  end

  def test_anonymous_user_not_authorized_to_perform_an_action
    # it doesn't matter for this test case if any permissions exist for the policy -
    # these can't affect anonymous user; hence can only check the final result of authorization

    # verify that the policy really provides access to anonymous users
    public_download_and_no_custom_sharing_policy =  Factory :policy, :sharing_scope=> Policy::ALL_SYSMO_USERS,:access_type=> Policy::ACCESSIBLE,:use_whitelist=>false,:use_blacklist=>false
    sop_with_public_download_and_no_custom_sharing = Factory :sop,:policy=>public_download_and_no_custom_sharing_policy
    temp = sop_with_public_download_and_no_custom_sharing.policy.sharing_scope
    assert temp < Policy::EVERYONE, "policy should not include anonymous users into the sharing scope"

    res = Seek::Permissions::Authorization.is_authorized?("view", nil, sop_with_public_download_and_no_custom_sharing, nil)
    assert !res, "anonymous user shouldn't have been allowed to 'view' the SOP - policy authorizes only registered users"
  end


end