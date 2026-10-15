require "test_helper"

module ParticipantPortal
  class AnalyticsControllerTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers

    setup do
      @user = users(:two) # participant user fixture
      @participant = participants(:two)
      sign_in @user
    end

    test "should get index" do
      get participant_portal_analytics_url
      assert_response :success
      assert_select "h3", text: /Performance Analytics/
    end

    test "should render turbo frame, habit heatmap and charts controller" do
      get participant_portal_analytics_url
      assert_response :success
      assert_select "turbo-frame#participant_analytics_frame"
      assert_select "[data-controller='participant-analytics']"
      assert_select ".heatmap-card"
    end

    test "should filter by date range" do
      get participant_portal_analytics_url(range: "7")
      assert_response :success

      get participant_portal_analytics_url(range: "all")
      assert_response :success

      get participant_portal_analytics_url(range: "custom", start_date: 10.days.ago.to_date.to_s, end_date: Date.current.to_s)
      assert_response :success
    end

    test "should filter by assignment" do
      assignment = assignments(:one) rescue nil
      if assignment
        get participant_portal_analytics_url(assignment_id: assignment.id)
        assert_response :success
      end
    end
  end
end
