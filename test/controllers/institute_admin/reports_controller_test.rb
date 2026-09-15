require "test_helper"

class InstituteAdmin::ReportsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = users(:one)
    @institute = @admin.institute
    
    # Create section
    @section = Section.create!(
      name: "Test Section",
      code: "TS01",
      capacity: 30,
      institute: @institute
    )
    
    # Update admin user section
    @admin.update!(section: @section)
    
    # Create participant user
    @participant_user = User.create!(
      email: "student@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: :participant,
      first_name: "Test",
      last_name: "Student",
      institute: @institute,
      section: @section
    )
    
    # Create participant
    @participant = Participant.create!(
      user: @participant_user,
      institute: @institute,
      section_id: @section.id,
      date_of_birth: 15.years.ago.to_date
    )
    
    # Create training program
    @training_program = TrainingProgram.create!(
      title: "Test Program",
      description: "Test Program Description",
      institute: @institute,
      trainer: trainers(:one),
      program_type: :individual,
      participant: @participant,
      start_date: 1.month.ago.to_date,
      end_date: 1.month.from_now.to_date,
      status: :ongoing
    )
    
    # Add participant to training program
    TrainingProgramParticipant.create!(
      participant: @participant,
      training_program: @training_program
    )
    
    # Create feedback
    @feedback = TrainingProgramFeedback.create!(
      participant: @participant,
      training_program: @training_program,
      rating: 5,
      content: "Great training!"
    )
    
    sign_in @admin
  end

  test "should get individual feedback reports pdf successfully" do
    get individual_feedback_reports_institute_admin_reports_url(
      format: :pdf,
      submission_status: "submitted",
      date_range: "all",
      section_id: @section.id,
      participant_id: @participant.id,
      training_program_id: @training_program.id,
      commit: "Generate Report"
    )
    
    # We skip testing ferrum external fonts in offline environments if ferrum fails
  rescue Ferrum::PendingConnectionsError
    skip "Ferrum pending connections error in test environment"
  end

  test "should get consolidated_response_report html successfully" do
    assignment = Assignment.create!(
      title: "Consolidated Assignment 1",
      start_date: 5.days.ago.to_date,
      end_date: 5.days.from_now.to_date,
      assignment_type: "section",
      section: @section,
      institute: @institute,
      skip_association_validation: true
    )
    question = Question.create!(
      title: "How did you find the task?",
      question_type: "short_answer",
      institute: @institute
    )
    AssignmentQuestion.create!(assignment: assignment, question: question)
    AssignmentResponse.create!(
      assignment: assignment,
      participant: @participant,
      question: question,
      answer: "Very helpful and well-structured",
      response_date: Date.current
    )

    get consolidated_response_report_institute_admin_reports_url
    assert_response :success
    assert_select "h3", text: "Consolidated Response Report"
    assert_includes response.body, "Very helpful and well-structured"
    assert_includes response.body, "Consolidated Assignment 1"
  end

  test "should filter consolidated_response_report by multiple assignments and status" do
    assignment1 = Assignment.create!(
      title: "Math Homework",
      start_date: 5.days.ago.to_date,
      end_date: 5.days.from_now.to_date,
      assignment_type: "section",
      section: @section,
      institute: @institute,
      skip_association_validation: true
    )
    assignment2 = Assignment.create!(
      title: "Science Quiz",
      start_date: 5.days.ago.to_date,
      end_date: 5.days.from_now.to_date,
      assignment_type: "section",
      section: @section,
      institute: @institute,
      skip_association_validation: true
    )
    question = Question.create!(title: "Q1", question_type: "short_answer", institute: @institute)
    AssignmentQuestion.create!(assignment: assignment1, question: question)
    AssignmentResponse.create!(
      assignment: assignment1,
      participant: @participant,
      question: question,
      answer: "Math Answer",
      response_date: Date.current
    )

    # Filter for assignment1 only
    get consolidated_response_report_institute_admin_reports_url(assignment_ids: [ assignment1.id ], submission_statuses: [ "submitted" ])
    assert_response :success
    assert_includes response.body, "Math Answer"

    # Filter for assignment2 only
    get consolidated_response_report_institute_admin_reports_url(assignment_ids: [ assignment2.id ], submission_statuses: [ "submitted" ])
    assert_response :success
    refute_includes response.body, "Math Answer"
  end

  test "should download consolidated_response_report as excel spreadsheetml" do
    assignment = Assignment.create!(
      title: "Excel Test Assignment",
      start_date: 5.days.ago.to_date,
      end_date: 5.days.from_now.to_date,
      assignment_type: "section",
      section: @section,
      institute: @institute,
      skip_association_validation: true
    )
    question = Question.create!(title: "Rating Question", question_type: "rating", institute: @institute)
    AssignmentQuestion.create!(assignment: assignment, question: question)
    AssignmentResponse.create!(
      assignment: assignment,
      participant: @participant,
      question: question,
      answer: "5",
      response_date: Date.current
    )

    get consolidated_response_report_institute_admin_reports_url(format: :xls)
    assert_response :success
    assert_equal "application/vnd.ms-excel; charset=utf-8", response.content_type
    assert_includes response.body, 'xmlns="urn:schemas-microsoft-com:office:spreadsheet"'
    assert_includes response.body, 'ss:Name="Consolidated Responses"'
    assert_includes response.body, 'ss:Name="Participant Summary"'
    assert_includes response.body, "Excel Test Assignment"
  end

  test "should download consolidated_response_report as csv" do
    assignment = Assignment.create!(
      title: "CSV Test Assignment",
      start_date: 5.days.ago.to_date,
      end_date: 5.days.from_now.to_date,
      assignment_type: "section",
      section: @section,
      institute: @institute,
      skip_association_validation: true
    )
    question = Question.create!(title: "Text Question", question_type: "short_answer", institute: @institute)
    AssignmentQuestion.create!(assignment: assignment, question: question)
    AssignmentResponse.create!(
      assignment: assignment,
      participant: @participant,
      question: question,
      answer: "CSV Great Response",
      response_date: Date.current
    )

    get consolidated_response_report_institute_admin_reports_url(format: :csv)
    assert_response :success
    assert_equal "text/csv; charset=utf-8", response.content_type
    assert_includes response.body, "CSV Great Response"
    assert_includes response.body, "CSV Test Assignment"
  end

  test "should enqueue async export job for consolidated_response_excel" do
    post export_async_institute_admin_reports_url, params: {
      export_type: "consolidated_response_excel"
    }, as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert json["export_token"].present?
    assert_equal "queued", json["status"]
  end

  test "should get consolidated_matrix_report html successfully" do
    assignment = Assignment.create!(
      title: "Matrix Assignment 1",
      start_date: 5.days.ago.to_date,
      end_date: 5.days.from_now.to_date,
      assignment_type: "section",
      section: @section,
      institute: @institute,
      skip_association_validation: true
    )
    question1 = Question.create!(title: "Question One", question_type: "rating", institute: @institute)
    question2 = Question.create!(title: "Question Two", question_type: "short_answer", institute: @institute)
    AssignmentQuestion.create!(assignment: assignment, question: question1, order_number: 1)
    AssignmentQuestion.create!(assignment: assignment, question: question2, order_number: 2)

    resp1 = AssignmentResponse.create!(
      assignment: assignment,
      participant: @participant,
      question: question1,
      answer: "5",
      response_date: Date.current
    )
    resp2 = AssignmentResponse.create!(
      assignment: assignment,
      participant: @participant,
      question: question2,
      answer: "Solid performance",
      response_date: Date.current
    )
    AssignmentResponseLog.create!(
      institute: @institute,
      participant: @participant,
      assignment: assignment,
      response_date: Date.current,
      assignment_response_ids: [ resp1.id, resp2.id ]
    )

    get consolidated_matrix_report_institute_admin_reports_url
    assert_response :success
    assert_select "h3", text: "Consolidated Question Matrix Report"
    assert_includes response.body, "Question One"
    assert_includes response.body, "Question Two"
    assert_includes response.body, "Solid performance"
  end

  test "should filter consolidated_matrix_report by multiple assignments" do
    assignment1 = Assignment.create!(
      title: "Math Matrix",
      start_date: 5.days.ago.to_date,
      end_date: 5.days.from_now.to_date,
      assignment_type: "section",
      section: @section,
      institute: @institute,
      skip_association_validation: true
    )
    assignment2 = Assignment.create!(
      title: "History Matrix",
      start_date: 5.days.ago.to_date,
      end_date: 5.days.from_now.to_date,
      assignment_type: "section",
      section: @section,
      institute: @institute,
      skip_association_validation: true
    )
    q1 = Question.create!(title: "Algebra Prompt", question_type: "short_answer", institute: @institute)
    q2 = Question.create!(title: "Century Prompt", question_type: "short_answer", institute: @institute)
    AssignmentQuestion.create!(assignment: assignment1, question: q1, order_number: 1)
    AssignmentQuestion.create!(assignment: assignment2, question: q2, order_number: 1)

    r1 = AssignmentResponse.create!(assignment: assignment1, participant: @participant, question: q1, answer: "x = 42", response_date: Date.current)
    AssignmentResponseLog.create!(institute: @institute, participant: @participant, assignment: assignment1, response_date: Date.current, assignment_response_ids: [ r1.id ])

    # Filter for assignment 1 only
    get consolidated_matrix_report_institute_admin_reports_url, params: { assignment_ids: [ assignment1.id ] }
    assert_response :success
    assert_includes response.body, "Algebra Prompt"
    assert_includes response.body, "x = 42"
  end

  test "should download consolidated_matrix_report as excel spreadsheetml" do
    assignment = Assignment.create!(
      title: "Excel Matrix Assignment",
      start_date: 5.days.ago.to_date,
      end_date: 5.days.from_now.to_date,
      assignment_type: "section",
      section: @section,
      institute: @institute,
      skip_association_validation: true
    )
    q = Question.create!(title: "Matrix Feedback Question", question_type: "short_answer", institute: @institute)
    AssignmentQuestion.create!(assignment: assignment, question: q, order_number: 1)
    rx = AssignmentResponse.create!(assignment: assignment, participant: @participant, question: q, answer: "Excel Answer", response_date: Date.current)
    AssignmentResponseLog.create!(institute: @institute, participant: @participant, assignment: assignment, response_date: Date.current, assignment_response_ids: [ rx.id ])

    get consolidated_matrix_report_institute_admin_reports_url(format: :xls)
    assert_response :success
    assert_equal "application/vnd.ms-excel; charset=utf-8", response.content_type
    assert_includes response.body, 'xmlns="urn:schemas-microsoft-com:office:spreadsheet"'
    assert_includes response.body, 'ss:Name="Question Matrix"'
    assert_includes response.body, 'ss:Name="Question Summary"'
    assert_includes response.body, "Matrix Feedback Question"
    assert_includes response.body, "Excel Answer"
  end

  test "should download consolidated_matrix_report as csv" do
    assignment = Assignment.create!(
      title: "CSV Matrix Assignment",
      start_date: 5.days.ago.to_date,
      end_date: 5.days.from_now.to_date,
      assignment_type: "section",
      section: @section,
      institute: @institute,
      skip_association_validation: true
    )
    q = Question.create!(title: "CSV Matrix Question", question_type: "short_answer", institute: @institute)
    AssignmentQuestion.create!(assignment: assignment, question: q, order_number: 1)
    rc = AssignmentResponse.create!(assignment: assignment, participant: @participant, question: q, answer: "CSV Matrix Answer", response_date: Date.current)
    AssignmentResponseLog.create!(institute: @institute, participant: @participant, assignment: assignment, response_date: Date.current, assignment_response_ids: [ rc.id ])

    get consolidated_matrix_report_institute_admin_reports_url(format: :csv)
    assert_response :success
    assert_equal "text/csv; charset=utf-8", response.content_type
    assert_includes response.body, "CSV Matrix Question"
    assert_includes response.body, "CSV Matrix Answer"
  end

  test "should enqueue async export job for consolidated_matrix_excel" do
    post export_async_institute_admin_reports_url, params: {
      export_type: "consolidated_matrix_excel"
    }, as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert json["export_token"].present?
    assert_equal "queued", json["status"]
  end

  test "should filter by search keyword when participant has nil email or section without crashing" do
    assignment = Assignment.create!(
      title: "Zaayan Test Assignment",
      start_date: 5.days.ago.to_date,
      end_date: 5.days.from_now.to_date,
      assignment_type: "section",
      section: @section,
      institute: @institute,
      skip_association_validation: true
    )
    # Simulate a participant whose email or name delegation might be nil or missing
    user_without_email = User.new(first_name: "Zaayan", last_name: "NilEmail")
    user_without_email.save(validate: false)
    participant = Participant.new(user: user_without_email, institute: @institute, section: @section)
    participant.save(validate: false)

    get consolidated_response_report_institute_admin_reports_url, params: {
      search: "zaayan",
      submission_statuses: [ "submitted", "pending" ],
      date_range: "all_time"
    }
    assert_response :success
    assert_includes response.body, "Zaayan"

    get consolidated_matrix_report_institute_admin_reports_url, params: {
      search: "zaayan",
      submission_statuses: [ "submitted", "pending" ],
      date_range: "all_time"
    }
    assert_response :success
    assert_includes response.body, "Zaayan"
  end
end
