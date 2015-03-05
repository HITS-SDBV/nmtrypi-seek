require 'test_helper'

class SearchTermStandardizeTest < ActiveSupport::TestCase
  test "to_standardize?" do
   assert_equal true, Seek::Search::SearchTermStandardize.to_standardize?("NMT-A0001")
   assert_equal true, Seek::Search::SearchTermStandardize.to_standardize?("NMT_A0001")
   assert_equal true, Seek::Search::SearchTermStandardize.to_standardize?("NMT-AH0001")
   assert_equal true, Seek::Search::SearchTermStandardize.to_standardize?("NMT-A1")
   assert_equal false, Seek::Search::SearchTermStandardize.to_standardize?("NMT-A")
   assert_equal false, Seek::Search::SearchTermStandardize.to_standardize?("abd-A001")
   assert_equal false, Seek::Search::SearchTermStandardize.to_standardize?("abdA001")
  end

  test "to_standardize" do
    assert_equal "nmt_a1", Seek::Search::SearchTermStandardize.to_standardize("NMT-A0001")
    assert_equal "nmt_a1", Seek::Search::SearchTermStandardize.to_standardize("NMT_A0001")
    assert_equal "nmt_ah1", Seek::Search::SearchTermStandardize.to_standardize("NMT-AH0001")
    assert_equal "nmt_a1", Seek::Search::SearchTermStandardize.to_standardize("nmt-A1")
    assert_equal "NMT-A", Seek::Search::SearchTermStandardize.to_standardize("NMT-A")
    assert_equal "abd-A001", Seek::Search::SearchTermStandardize.to_standardize("abd-A001")
    assert_equal "abdA001", Seek::Search::SearchTermStandardize.to_standardize("abdA001")
  end
end