require "test_helper"

class Admin::InstitutesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = users(:master_admin)
    sign_in @admin

    @active_institute = Institute.create!(
      name: "Active Test Institute",
      code: "ACT001",
      email: "active@testinstitute.org",
      contact_number: "1234567890",
      institution_type: "School",
      active: true
    )
    @inactive_institute = Institute.create!(
      name: "Inactive Test Institute",
      code: "INACT001",
      email: "inactive@testinstitute.org",
      contact_number: "0987654321",
      institution_type: "School",
      active: false
    )
  end

  test "should get index and default to active institutes" do
    get admin_institutes_path
    assert_response :success

    # Active status button should have active class by default
    assert_select "button.status-filter-btn.active[data-filter='active']"
    assert_select "button.status-filter-btn.active[data-filter='all']", count: 0

    # Active institute should be visible (not hidden with display: none)
    assert_select "tr.institute-row[data-code='act001']" do |rows|
      assert_not_equal "display: none;", rows.first["style"]
    end

    # Inactive institute row should be hidden by default
    assert_select "tr.institute-row[data-code='inact001'][style*='display: none;']"
  end

  test "should allow filtering all institutes via status param" do
    get admin_institutes_path(status: "all")
    assert_response :success

    assert_select "button.status-filter-btn.active[data-filter='all']"
    assert_select "button.status-filter-btn.active[data-filter='active']", count: 0

    assert_select "tr.institute-row[data-code='act001']" do |rows|
      assert_not_equal "display: none;", rows.first["style"]
    end
    assert_select "tr.institute-row[data-code='inact001']" do |rows|
      assert_not_equal "display: none;", rows.first["style"]
    end
  end

  test "should allow filtering inactive institutes via status param" do
    get admin_institutes_path(status: "inactive")
    assert_response :success

    assert_select "button.status-filter-btn.active[data-filter='inactive']"
    assert_select "button.status-filter-btn.active[data-filter='active']", count: 0

    assert_select "tr.institute-row[data-code='act001'][style*='display: none;']"
    assert_select "tr.institute-row[data-code='inact001']" do |rows|
      assert_not_equal "display: none;", rows.first["style"]
    end
  end
end
