require 'test_helper'

class DataMatchTest < ActiveSupport::TestCase
  test "compound_name?" do
   assert_equal true, Seek::Data::DataMatch.compound_name?("NMT-A0001")
   assert_equal true, Seek::Data::DataMatch.compound_name?("NMT_A0001")
   assert_equal true, Seek::Data::DataMatch.compound_name?("NMT-AH0001")
   assert_equal true, Seek::Data::DataMatch.compound_name?("NMT-A1")
   assert_equal false, Seek::Data::DataMatch.compound_name?("NMT-A")
   assert_equal false, Seek::Data::DataMatch.compound_name?("abd-A001")
   assert_equal false, Seek::Data::DataMatch.compound_name?("abdA001")
  end

  test "standardize_compound_name" do
    assert_equal "nmt_a1", Seek::Data::DataMatch.standardize_compound_name("NMT-A0001")
    assert_equal "nmt_a1", Seek::Data::DataMatch.standardize_compound_name("NMT_A0001")
    assert_equal "nmt_ah1", Seek::Data::DataMatch.standardize_compound_name("NMT-AH0001")
    assert_equal "nmt_a1", Seek::Data::DataMatch.standardize_compound_name("nmt-A1")
    assert_equal "NMT-A", Seek::Data::DataMatch.standardize_compound_name("NMT-A")
    assert_equal "abd-A001", Seek::Data::DataMatch.standardize_compound_name("abd-A001")
    assert_equal "abdA001", Seek::Data::DataMatch.standardize_compound_name("abdA001")
  end
end