require "test_helper"

class InstituteAdmin::ParticipantsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = users(:one)
    @institute = @admin.institute
    @section_a = Section.create!(name: "Alpha Section", code: "SEC-A-#{SecureRandom.hex(3)}", capacity: 50, institute: @institute)
    @section_b = Section.create!(name: "Beta Section", code: "SEC-B-#{SecureRandom.hex(3)}", capacity: 50, institute: @institute)

    @user_student = User.create!(
      email: "student_#{SecureRandom.hex(4)}@test.com",
      password: "password123",
      password_confirmation: "password123",
      role: :participant,
      first_name: "John",
      last_name: "Doe",
      phone: "9876543210",
      active: true,
      institute: @institute,
      section: @section_a
    )
    @participant_student = Participant.create!(
      user: @user_student,
      institute: @institute,
      section_id: @section_a.id,
      participant_type: :student,
      date_of_birth: 16.years.ago.to_date
    )

    @user_guardian = User.create!(
      email: "guardian_#{SecureRandom.hex(4)}@test.com",
      password: "password123",
      password_confirmation: "password123",
      role: :participant,
      first_name: "Jane",
      last_name: "Doe",
      phone: "9123456780",
      active: true,
      institute: @institute,
      section: @section_b
    )
    @participant_guardian = Participant.create!(
      user: @user_guardian,
      institute: @institute,
      section_id: @section_b.id,
      participant_type: :guardian,
      date_of_birth: 40.years.ago.to_date
    )

    sign_in @admin
  end

  test "index renders approved participants with scorecards" do
    get institute_admin_participants_path(approved: "true")
    assert_response :success
    assert_select ".inst-kpi-card", minimum: 4
    assert_includes response.body, "Total Approved"
    assert_includes response.body, "Students"
    assert_includes response.body, "Guardians"
    assert_includes response.body, "Employees"
    assert_includes response.body, "Mobile Number"
    assert_includes response.body, "9876543210"
  end

  test "search filters by mobile number" do
    get institute_admin_participants_path(approved: "true", search: "9876543210")
    assert_response :success
    assert_includes response.body, "John Doe"
    assert_not_includes response.body, "Jane Doe"

    get institute_admin_participants_path(approved: "true", search: "9123456780")
    assert_response :success
    assert_includes response.body, "Jane Doe"
    assert_not_includes response.body, "John Doe"
  end

  test "filter by participant_types multi-select" do
    get institute_admin_participants_path(approved: "true", participant_types: ["student"])
    assert_response :success
    assert_includes response.body, "John Doe"
    assert_not_includes response.body, "Jane Doe"

    get institute_admin_participants_path(approved: "true", participant_types: ["guardian"])
    assert_response :success
    assert_includes response.body, "Jane Doe"
    assert_not_includes response.body, "John Doe"

    get institute_admin_participants_path(approved: "true", participant_types: ["student", "guardian"])
    assert_response :success
    assert_includes response.body, "John Doe"
    assert_includes response.body, "Jane Doe"
  end

  test "filter by section_ids multi-select" do
    get institute_admin_participants_path(approved: "true", section_ids: [@section_a.id])
    assert_response :success
    assert_includes response.body, "John Doe"
    assert_not_includes response.body, "Jane Doe"

    get institute_admin_participants_path(approved: "true", section_ids: [@section_b.id])
    assert_response :success
    assert_includes response.body, "Jane Doe"
    assert_not_includes response.body, "John Doe"
  end

  test "backwards compatible with single participant_type and section_id params" do
    get institute_admin_participants_path(approved: "true", participant_type: "student", section_id: @section_a.id)
    assert_response :success
    assert_includes response.body, "John Doe"
    assert_not_includes response.body, "Jane Doe"
  end
end
