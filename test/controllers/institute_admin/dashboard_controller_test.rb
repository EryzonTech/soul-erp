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
    assert_select ".chart-header-title", text: /Assignment submission/i
    assert_select ".chart-controls-toolbar", minimum: 1
    assert_select "#assignment_submission_range_picker", 1
    assert_select "#backlog_range_picker", 0
    assert_select "#by_assignment_picker", 1
    assert_select "#by_section_picker", 1
    assert_select "#not_submitted_picker", 1
    assert_select "#pending_section_picker", 1
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

  test "chart_data returns not submitted by assignment data with single date and date range" do
    # Single date
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

    # Date range
    get institute_admin_dashboard_chart_data_url(
      chart: "not_submitted_assignment",
      start_date: (Date.current - 2.days).to_s,
      end_date: Date.current.to_s
    )
    assert_response :success

    json_range = JSON.parse(response.body)
    assert json_range["success"]
    assert json_range["labels"].is_a?(Array)
    assert json_range["data"].is_a?(Array)
    assert_includes json_range["labels"], "Daily Reflections Assignment"
  end

  test "chart_data returns pending by section data with single date and date range" do
    # Single date
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

    # Date range
    get institute_admin_dashboard_chart_data_url(
      chart: "pending_section",
      start_date: (Date.current - 2.days).to_s,
      end_date: Date.current.to_s
    )
    assert_response :success

    json_range = JSON.parse(response.body)
    assert json_range["success"]
    assert json_range["labels"].is_a?(Array)
    assert json_range["data"].is_a?(Array)
    assert_includes json_range["labels"], "Test Section A"
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

  test "should get dashboard index with unified feedback, leaderboards, and duration" do
    get institute_admin_root_url
    assert_response :success

    # Unified Feedback by Training Program
    assert_select ".chart-header-title", text: /Feedback by Training Program/
    assert_select "#tpfProgramDropdown", 1
    assert_select "#tpfModeReceivedPending", 1
    assert_select "#tpfModeParticipantType", 1
    assert_select "#tpf-received-summary", 1
    assert_select "#tpf-pending-summary", 1

    # Top & Bottom Submitting Participants Leaderboards
    assert_select ".chart-header-title", text: /Top Submitting Participants/
    assert_select ".chart-header-title", text: /Bottom Submitting Participants/
    assert_select "#topLeaderboardTable", 1
    assert_select "#bottomLeaderboardTable", 1
    assert_select "#topLeaderboardAssignment", 1
    assert_select "#bottomLeaderboardAssignment", 1

    # Recent Training Programs Duration Column
    assert_select "table.modern-table thead tr th", text: /Duration/
  end

  test "streak_leaderboards endpoint returns top and bottom rankings" do
    get institute_admin_dashboard_streak_leaderboards_url(assignment_id: @assignment.id, top_limit: 5, bottom_limit: 5)
    assert_response :success

    json = JSON.parse(response.body)
    assert json["success"]
    assert json["top"].is_a?(Array)
    assert json["bottom"].is_a?(Array)
    assert_equal @assignment.title, json["assignment"]["title"]
    assert_equal 2, json["top"].size
    assert_equal 1, json["top"].first["rank"]
    assert_equal "John Student", json["top"].first["name"]
    assert_equal 1, json["top"].first["streak"]
    assert_equal 2, json["bottom"].size
    assert_equal 1, json["bottom"].first["rank"]
    assert_equal "Mary Guardian", json["bottom"].first["name"]
    assert_equal 0, json["bottom"].first["streak"]
  end

  test "dense ranking ensures ranks increment sequentially without skipping when ties occur" do
    user2 = User.create!(
      email: "student2@example.com",
      password: "password123",
      role: :participant,
      first_name: "Alice",
      last_name: "TiedTop",
      institute: @institute,
      section: @section,
      active: true
    )
    participant2 = Participant.create!(
      user: user2,
      institute: @institute,
      section_id: @section.id,
      participant_type: "student",
      date_of_birth: 17.years.ago.to_date
    )

    user3 = User.create!(
      email: "student3@example.com",
      password: "password123",
      role: :participant,
      first_name: "Bob",
      last_name: "Middle",
      institute: @institute,
      section: @section,
      active: true
    )
    Participant.create!(
      user: user3,
      institute: @institute,
      section_id: @section.id,
      participant_type: "student",
      date_of_birth: 18.years.ago.to_date
    )

    resp2 = AssignmentResponse.create!(
      assignment: @assignment,
      participant: participant2,
      question: @question,
      answer: "Tied with John",
      response_date: Date.current
    )
    AssignmentResponseLog.log_responses(
      assignment: @assignment,
      participant: participant2,
      response_ids: [ resp2.id ],
      response_date: Date.current
    )

    get institute_admin_dashboard_streak_leaderboards_url(assignment_id: @assignment.id, top_limit: 10, bottom_limit: 10)
    assert_response :success

    json = JSON.parse(response.body)
    assert json["success"]

    top_ranks = json["top"].map { |p| p["rank"] }
    assert_equal [ 1, 1, 2, 2 ], top_ranks

    bottom_ranks = json["bottom"].map { |p| p["rank"] }
    assert_equal [ 1, 1, 2, 2 ], bottom_ranks
  end

  test "dashboard index runs efficiently with bounded query count and no N+1 regression" do
    query_count = 0
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_name, _start, _finish, _id, payload|
      next if payload[:name] == "SCHEMA" || payload[:sql] =~ /pg_tables|pg_attribute/i
      query_count += 1
    end

    get institute_admin_root_url
    assert_response :success

    ActiveSupport::Notifications.unsubscribe(subscriber)

    # Ensure query count remains bounded and does not regress
    assert query_count <= 35, "Expected dashboard to execute <= 35 queries, executed #{query_count}"
  end

  test "dashboard total participants and distribution excludes inactive and soft deleted participants" do
    initial_count = @institute.participants.joins(:user).where(users: { active: true }).count
    get institute_admin_root_url
    assert_response :success
    assert_select ".stat-card-participants .stat-value", text: initial_count.to_s
    assert_select ".stat-card-participants", text: /Students:\s*1/
    assert_select ".stat-card-participants", text: /Guardians:\s*1/

    # Deactivate the guardian user
    @guardian_user.update!(active: false)

    get institute_admin_root_url
    assert_response :success
    assert_select ".stat-card-participants .stat-value", text: (initial_count - 1).to_s
    assert_select ".stat-card-participants", text: /Students:\s*1/
    assert_select ".stat-card-participants", text: /Guardians:\s*0/

    # Soft delete the student participant
    @participant.soft_delete!

    get institute_admin_root_url
    assert_response :success
    assert_select ".stat-card-participants .stat-value", text: (initial_count - 2).to_s
    assert_select ".stat-card-participants", text: /Students:\s*0/
    assert_select ".stat-card-participants", text: /Guardians:\s*0/
  end

  test "streak leaderboards sorts primarily by total submitted days for top and bottom with streak tie breaker" do
    # Create an assignment spanning 5 days ending today
    test_asg = Assignment.create!(
      title: "Sort Order Verification Assignment",
      assignment_type: "individual",
      start_date: 4.days.ago.beginning_of_day,
      end_date: Time.current.end_of_day,
      institute: @institute,
      active: true,
      skip_association_validation: true
    )
    AssignmentQuestion.create!(assignment: test_asg, question: @question)

    # Participant HighDaysLowStreak: 3 submitted days (4 days ago, 3 days ago, today) -> streak 1, submissions 3
    u_high = User.create!(email: "highdays@example.com", password: "password123", role: :participant, first_name: "High", last_name: "Days", institute: @institute, section: @section, active: true)
    p_high = Participant.create!(user: u_high, institute: @institute, section_id: @section.id, participant_type: "student", date_of_birth: 16.years.ago.to_date)
    AssignmentParticipant.create!(assignment: test_asg, participant: p_high)

    [ 4.days.ago.to_date, 3.days.ago.to_date, Date.current ].each do |d|
      r = AssignmentResponse.create!(assignment: test_asg, participant: p_high, question: @question, answer: "ok", response_date: d)
      AssignmentResponseLog.log_responses(assignment: test_asg, participant: p_high, response_ids: [ r.id ], response_date: d)
    end

    # Participant LowDaysHighStreak: 2 submitted days (yesterday, today) -> streak 2, submissions 2
    u_low = User.create!(email: "lowdays@example.com", password: "password123", role: :participant, first_name: "Low", last_name: "Days", institute: @institute, section: @section, active: true)
    p_low = Participant.create!(user: u_low, institute: @institute, section_id: @section.id, participant_type: "student", date_of_birth: 16.years.ago.to_date)
    AssignmentParticipant.create!(assignment: test_asg, participant: p_low)

    [ 1.day.ago.to_date, Date.current ].each do |d|
      r = AssignmentResponse.create!(assignment: test_asg, participant: p_low, question: @question, answer: "ok", response_date: d)
      AssignmentResponseLog.log_responses(assignment: test_asg, participant: p_low, response_ids: [ r.id ], response_date: d)
    end

    # Participant ZeroDays: 0 submitted days -> streak 0, submissions 0
    u_zero = User.create!(email: "zerodays@example.com", password: "password123", role: :participant, first_name: "Zero", last_name: "Days", institute: @institute, section: @section, active: true)
    p_zero = Participant.create!(user: u_zero, institute: @institute, section_id: @section.id, participant_type: "student", date_of_birth: 16.years.ago.to_date)
    AssignmentParticipant.create!(assignment: test_asg, participant: p_zero)

    get institute_admin_dashboard_streak_leaderboards_url(assignment_id: test_asg.id, top_limit: 10, bottom_limit: 10)
    assert_response :success

    json = JSON.parse(response.body)
    assert json["success"]

    # Top Submitting Participants: highest submissions at the top
    top_names = json["top"].map { |p| p["name"] }
    assert_equal "High Days", top_names.first, "Participant with 3 days must rank higher than participant with 2 days despite lower streak"
    assert_equal "Low Days", top_names.second
    assert_equal "Zero Days", top_names.last

    assert_equal 3, json["top"].first["total_submissions"]
    assert_equal 2, json["top"].second["total_submissions"]
    assert_equal 0, json["top"].last["total_submissions"]

    # Bottom Submitting Participants: fewest submissions at the top
    bottom_names = json["bottom"].map { |p| p["name"] }
    assert_equal "Zero Days", bottom_names.first, "Participant with 0 days must be at the top of bottom submitting participants"
    assert_equal "Low Days", bottom_names.second
    assert_equal "High Days", bottom_names.last

    assert_equal 0, json["bottom"].first["total_submissions"]
    assert_equal 2, json["bottom"].second["total_submissions"]
    assert_equal 3, json["bottom"].last["total_submissions"]
  end
end
