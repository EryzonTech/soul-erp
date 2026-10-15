# frozen_string_literal: true

require "test_helper"

module ParticipantPortal
  class ResponsesControllerTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers

    setup do
      @user = users(:two)
      @participant = participants(:two)
      @institute = institutes(:two)
      @assignment = assignments(:two)
      @log = assignment_response_logs(:two)

      sign_in @user
    end

    test "should redirect unauthenticated users" do
      sign_out @user
      get participant_portal_responses_url
      assert_response :redirect
    end

    test "should get index" do
      get participant_portal_responses_url
      assert_response :success
      assert_select "h4", text: /My Responses/
    end

    test "should filter by date range presets" do
      get participant_portal_responses_url(range: "today")
      assert_response :success

      get participant_portal_responses_url(range: "7")
      assert_response :success

      get participant_portal_responses_url(range: "30")
      assert_response :success

      get participant_portal_responses_url(range: "all")
      assert_response :success
    end

    test "should filter by custom date range" do
      get participant_portal_responses_url(range: "custom", start_date: "2025-01-01", end_date: "2025-12-31")
      assert_response :success

      get participant_portal_responses_url(start_date: "2025-01-01")
      assert_response :success

      get participant_portal_responses_url(end_date: "2025-12-31")
      assert_response :success
    end

    test "should filter by assignment_id" do
      get participant_portal_responses_url(assignment_id: @assignment.id)
      assert_response :success
    end

    test "should search by query keyword" do
      get participant_portal_responses_url(query: "reflection")
      assert_response :success
    end

    test "should show submission details" do
      get participant_portal_response_url(@log)
      assert_response :success
      assert_select "h4", text: /#{@assignment.title}/
    end

    test "should not allow participant to access another participant log" do
      other_log = assignment_response_logs(:one)
      get participant_portal_response_url(other_log)
      assert_response :not_found
    end
  end
end
