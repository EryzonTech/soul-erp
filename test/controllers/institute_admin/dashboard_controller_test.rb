require "test_helper"

class InstituteAdmin::DashboardControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = users(:one)
    @institute = @admin.institute

    @section = Section.create!(
      name: "Test Section A",
      code: "TSA01",
      capacity: 30,
      institute: @institute
    )

    @admin.update!(section: @section)

    @participant_user = User.create!(
      email: "dashboard_student@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: :participant,
      first_name: "John",
      last_name: "Student",
      institute: @institute,
      section: @section,
      active: true
    )

    @participant = Participant.create!(
      user: @participant_user,
      institute: @institute,
      section_id: @section.id,
      participant_type: "student",
      date_of_birth: 16.years.ago.to_date
    )

    @guardian_user = User.create!(
      email: "dashboard_guardian@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: :participant,
      first_name: "Mary",
      last_name: "Guardian",
      institute: @institute,
      section: @section,
      active: true
    )

    @guardian = Participant.create!(
      user: @guardian_user,
      institute: @institute,
      section_id: @section.id,
      participant_type: "guardian",
      date_of_birth: 40.years.ago.to_date
    )

    @assignment = Assignment.create!(
      title: "Daily Reflections Assignment",
      start_date: 7.days.ago.to_date,
      end_date: 7.days.from_now.to_date,
      assignment_type: "section",
      section: @section,
      institute: @institute,
      active: true,
      skip_association_validation: true
    )

    @question = Question.create!(
      title: "How did your study session go?",
      question_type: "short_answer",
      institute: @institute
    )
    AssignmentQuestion.create!(assignment: @assignment, question: @question)

    resp = AssignmentResponse.create!(
      assignment: @assignment,
      participant: @participant,
      question: @question,
      answer: "Went well!",
      response_date: Date.current
    )

    AssignmentResponseLog.log_responses(
      assignment: @assignment,
      participant: @participant,
      response_ids: [ resp.id ],
      response_date: Date.current
    )

    sign_in @admin
  end

  test "should get dashboard index with enhanced metrics and participant breakdown" do
    get institute_admin_root_url
    assert_response :success

    # Scorecard participant breakdowns
    assert_select ".stat-breakdown", minimum: 1
    assert_select ".stat-breakdown-pill", minimum: 1

    # Assignment submission graph and controls
    assert_select "h5", text: /Assignment submission/
    assert_select ".chart-controls-toolbar", minimum: 1
    assert_select "#assignment_submission_range_picker", 1
    assert_select "#backlog_range_picker", 1
    assert_select "#by_assignment_picker", 1
    assert_select "#by_section_picker", 1
    assert_select "#not_submitted_picker", 1
    assert_select "#pending_section_picker", 1

    # Separate Backlog Trend card
    assert_select "h5", text: /Backlog Trend/
  end

  test "chart_data returns assignment submission data with participant type breakdowns" do
    get institute_admin_dashboard_chart_data_url(
      chart: "assignment_submission",
      start_date: (Date.current - 13.days).to_s,
      end_date: Date.current.to_s
    )
    assert_response :success

    json = JSON.parse(response.body)
    assert json["success"]
    assert json["labels"].is_a?(Array)
    assert json["total_data"].is_a?(Array)
    assert json["student_data"].is_a?(Array)
    assert json["guardian_data"].is_a?(Array)
    assert json["employee_data"].is_a?(Array)
    assert json["backlog_data"].is_a?(Array)
    assert_equal 14, json["labels"].size
  end

  test "chart_data returns submissions by assignment with full assignment names" do
    get institute_admin_dashboard_chart_data_url(
      chart: "submissions_by_assignment",
      start_date: Date.current.to_s,
      end_date: Date.current.to_s
    )
    assert_response :success

    json = JSON.parse(response.body)
    assert json["success"]
    assert json["labels"].is_a?(Array)
    assert json["data"].is_a?(Array)
    assert_includes json["labels"], "Daily Reflections Assignment"
  end

  test "chart_data returns submissions by section with full section names" do
    get institute_admin_dashboard_chart_data_url(
      chart: "submissions_by_section",
      start_date: Date.current.to_s,
      end_date: Date.current.to_s
    )
    assert_response :success

    json = JSON.parse(response.body)
    assert json["success"]
    assert json["labels"].is_a?(Array)
    assert json["data"].is_a?(Array)
    assert_includes json["labels"], "Test Section A"
  end

  test "chart_data returns not submitted by assignment data" do
    get institute_admin_dashboard_chart_data_url(
      chart: "not_submitted_assignment",
      date: Date.current.to_s
    )
    assert_response :success

    json = JSON.parse(response.body)
    assert json["success"]
    assert json["labels"].is_a?(Array)
    assert json["data"].is_a?(Array)
    assert_includes json["labels"], "Daily Reflections Assignment"
    assert_equal [ 1 ], json["data"]
  end

  test "chart_data returns pending by section data" do
    get institute_admin_dashboard_chart_data_url(
      chart: "pending_section",
      date: Date.current.to_s
    )
    assert_response :success

    json = JSON.parse(response.body)
    assert json["success"]
    assert json["labels"].is_a?(Array)
    assert json["data"].is_a?(Array)
    assert_includes json["labels"], "Test Section A"
    assert_equal [ 1 ], json["data"]
  end

  test "chart_data returns backlog trend data for date range" do
    get institute_admin_dashboard_chart_data_url(
      chart: "backlog_trend",
      start_date: (Date.current - 13.days).to_s,
      end_date: Date.current.to_s
    )
    assert_response :success

    json = JSON.parse(response.body)
    assert json["success"]
    assert json["labels"].is_a?(Array)
    assert json["data"].is_a?(Array)
    assert_equal 14, json["labels"].size
  end

  test "chart_data returns 400 bad request for invalid chart parameter" do
    get institute_admin_dashboard_chart_data_url(chart: "unknown_chart")
    assert_response :bad_request

    json = JSON.parse(response.body)
    assert_equal false, json["success"]
  end
end
