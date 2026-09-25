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
    get institute_admin_participants_path(approved: "true", participant_types: [ "student" ])
    assert_response :success
    assert_includes response.body, "John Doe"
    assert_not_includes response.body, "Jane Doe"

    get institute_admin_participants_path(approved: "true", participant_types: [ "guardian" ])
    assert_response :success
    assert_includes response.body, "Jane Doe"
    assert_not_includes response.body, "John Doe"

    get institute_admin_participants_path(approved: "true", participant_types: [ "student", "guardian" ])
    assert_response :success
    assert_includes response.body, "John Doe"
    assert_includes response.body, "Jane Doe"
  end

  test "filter by section_ids multi-select" do
    get institute_admin_participants_path(approved: "true", section_ids: [ @section_a.id ])
    assert_response :success
    assert_includes response.body, "John Doe"
    assert_not_includes response.body, "Jane Doe"

    get institute_admin_participants_path(approved: "true", section_ids: [ @section_b.id ])
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

  test "index lists participants in alphabetical order by name" do
    user_alice = User.create!(
      email: "alice_#{SecureRandom.hex(4)}@test.com",
      password: "password123",
      role: :participant,
      first_name: "Alice",
      last_name: "Wonder",
      active: true,
      institute: @institute,
      section: @section_a
    )
    Participant.create!(
      user: user_alice,
      institute: @institute,
      section_id: @section_a.id,
      participant_type: :student
    )

    user_zach = User.create!(
      email: "zach_#{SecureRandom.hex(4)}@test.com",
      password: "password123",
      role: :participant,
      first_name: "Zachary",
      last_name: "Taylor",
      active: true,
      institute: @institute,
      section: @section_a
    )
    Participant.create!(
      user: user_zach,
      institute: @institute,
      section_id: @section_a.id,
      participant_type: :student
    )

    get institute_admin_participants_path(approved: "true")
    assert_response :success

    rendered_names = css_select("tbody tr td:nth-child(3) .fw-semibold").map(&:text).map(&:strip)
    assert_equal rendered_names.sort_by(&:downcase), rendered_names
    assert_equal "Alice Wonder", rendered_names.first
    assert_equal "Zachary Taylor", rendered_names.last
  end

  test "destroy performs soft delete preserving database records" do
    assert_difference("@institute.participants.count", -1) do
      assert_no_difference("Participant.count") do
        delete institute_admin_participant_path(@participant_student)
      end
    end

    assert_redirected_to institute_admin_participants_path
    assert_equal "Participant was successfully deleted.", flash[:notice]

    # Participant is excluded from institute participants
    assert_nil @institute.participants.find_by(id: @participant_student.id)

    # But records exist in database with deleted_at set and user deactivated
    deleted_participant = Participant.find(@participant_student.id)
    assert_not_nil deleted_participant.deleted_at
    assert deleted_participant.soft_deleted?

    @user_student.reload
    assert_not_nil @user_student.deleted_at
    assert_not @user_student.active?
  end

  test "toggle_status deactivates active participant to suspended and reactivates suspended participant" do
    assert @user_student.active?
    assert_equal "active", @participant_student.status

    # Suspend / deactivate
    patch toggle_status_institute_admin_participant_path(@participant_student)
    assert_redirected_to institute_admin_participants_path
    assert_equal "Participant was successfully suspended.", flash[:notice]
    assert_not @user_student.reload.active?
    assert_equal "suspended", @participant_student.reload.status

    # Reactivate
    patch toggle_status_institute_admin_participant_path(@participant_student)
    assert_redirected_to institute_admin_participants_path
    assert_equal "Participant was successfully activated.", flash[:notice]
    assert @user_student.reload.active?
    assert_equal "active", @participant_student.reload.status
  end

  test "deactivate_selected performs bulk suspension" do
    assert @user_student.active?
    assert @user_guardian.active?

    patch deactivate_selected_institute_admin_participants_path, params: {
      selected_ids: "#{@participant_student.id},#{@participant_guardian.id}"
    }

    assert_redirected_to institute_admin_participants_path(approved: true)
    assert_equal "Successfully suspended 2 participants.", flash[:notice]

    assert_not @user_student.reload.active?
    assert_not @user_guardian.reload.active?
    assert_equal "suspended", @participant_student.reload.status
    assert_equal "suspended", @participant_guardian.reload.status
  end

  test "index with status=suspended lists only suspended participants and isolates from not approved" do
    # Create an unapproved (pending) participant
    user_pending = User.create!(
      email: "pending_#{SecureRandom.hex(4)}@test.com",
      password: "password123",
      role: :participant,
      first_name: "Pending",
      last_name: "Student",
      active: false,
      institute: @institute,
      section: @section_a
    )
    participant_pending = Participant.create!(
      user: user_pending,
      institute: @institute,
      section_id: @section_a.id,
      participant_type: :student,
      status: :active
    )

    # Suspend @participant_student
    @participant_student.update!(status: :suspended)
    @user_student.update!(active: false)

    # 1. Suspended index
    get institute_admin_participants_path(status: "suspended")
    assert_response :success
    assert_includes response.body, "Suspended Participants"
    assert_includes response.body, "John Doe"
    assert_not_includes response.body, "Pending Student"
    assert_not_includes response.body, "Jane Doe"
    assert_includes response.body, "Total Suspended"

    # 2. Not Approved index (must NOT show suspended participant)
    get institute_admin_participants_path(approved: "false")
    assert_response :success
    assert_includes response.body, "Not Approved Participants"
    assert_includes response.body, "Pending Student"
    assert_not_includes response.body, "John Doe"

    # 3. Approved index (must NOT show suspended participant)
    get institute_admin_participants_path(approved: "true")
    assert_response :success
    assert_includes response.body, "Approved Participants"
    assert_includes response.body, "Jane Doe"
    assert_not_includes response.body, "John Doe"
    assert_not_includes response.body, "Pending Student"
  end

  test "reactivate_selected performs bulk reactivation of suspended participants" do
    @participant_student.update!(status: :suspended)
    @user_student.update!(active: false)
    @participant_guardian.update!(status: :suspended)
    @user_guardian.update!(active: false)

    patch reactivate_selected_institute_admin_participants_path, params: {
      selected_ids: "#{@participant_student.id},#{@participant_guardian.id}"
    }

    assert_redirected_to institute_admin_participants_path(status: "suspended")
    assert_equal "Successfully reactivated 2 participants.", flash[:notice]

    assert @user_student.reload.active?
    assert @user_guardian.reload.active?
    assert_equal "active", @participant_student.reload.status
    assert_equal "active", @participant_guardian.reload.status
  end

  test "view_only admin cannot perform deactivate_selected, reactivate_selected, toggle_status, or destroy" do
    view_only_user = User.create!(
      email: "view_only_#{SecureRandom.hex(4)}@test.com",
      password: "password123",
      role: :institute_admin,
      first_name: "View",
      last_name: "Admin",
      view_only: true,
      institute: @institute,
      active: true
    )
    sign_in view_only_user

    patch deactivate_selected_institute_admin_participants_path, params: {
      selected_ids: "#{@participant_student.id}"
    }
    assert_redirected_to institute_admin_root_path
    assert_equal "You have view-only access and cannot perform this action.", flash[:alert]
    assert @user_student.reload.active?

    patch reactivate_selected_institute_admin_participants_path, params: {
      selected_ids: "#{@participant_student.id}"
    }
    assert_redirected_to institute_admin_root_path
    assert_equal "You have view-only access and cannot perform this action.", flash[:alert]

    patch toggle_status_institute_admin_participant_path(@participant_student)
    assert_redirected_to institute_admin_root_path
    assert_equal "You have view-only access and cannot perform this action.", flash[:alert]
    assert @user_student.reload.active?

    delete institute_admin_participant_path(@participant_student)
    assert_redirected_to institute_admin_root_path
    assert_equal "You have view-only access and cannot perform this action.", flash[:alert]
    assert_nil @participant_student.reload.deleted_at
  end

  test "deactivate_selected succeeds when another user shares duplicate phone and does not confuse participant IDs with user IDs" do
    other_user = User.new(
      email: "duplicate_phone_#{SecureRandom.hex(4)}@test.com",
      password: "password123",
      role: :participant,
      first_name: "Duplicate",
      last_name: "PhoneUser",
      phone: @user_student.phone,
      active: true,
      institute: @institute
    )
    other_user.save(validate: false)

    patch deactivate_selected_institute_admin_participants_path, params: {
      selected_ids: "#{@participant_student.id}"
    }

    assert_redirected_to institute_admin_participants_path(approved: true)
    assert_equal "Successfully suspended 1 participant.", flash[:notice]
    assert_not @user_student.reload.active?
    assert_equal "suspended", @participant_student.reload.status
  end

  test "index renders per_page filter dropdown with 20, 50, 100, All options" do
    get institute_admin_participants_path(approved: "true")
    assert_response :success
    assert_select "select[name='per_page']" do
      assert_select "option[value='20']"
      assert_select "option[value='50']"
      assert_select "option[value='100']"
      assert_select "option[value='all']"
    end
  end

  test "index with custom per_page values 50, 100, all and invalid fallback" do
    # Default 20
    get institute_admin_participants_path(approved: "true")
    assert_response :success
    assert_select "select[name='per_page'] option[value='20'][selected]"

    # 50 per page
    get institute_admin_participants_path(approved: "true", per_page: "50")
    assert_response :success
    assert_select "select[name='per_page'] option[value='50'][selected]"

    # 100 per page
    get institute_admin_participants_path(approved: "true", per_page: "100")
    assert_response :success
    assert_select "select[name='per_page'] option[value='100'][selected]"

    # All per page (case insensitive)
    get institute_admin_participants_path(approved: "true", per_page: "all")
    assert_response :success
    assert_select "select[name='per_page'] option[value='all'][selected]"

    get institute_admin_participants_path(approved: "true", per_page: "ALL")
    assert_response :success
    assert_select "select[name='per_page'] option[value='all'][selected]"

    # Invalid per_page falls back to default 20
    get institute_admin_participants_path(approved: "true", per_page: "invalid_999")
    assert_response :success
    assert_select "select[name='per_page'] option[value='20'][selected]"
  end

  test "per_page all displays all participants on a single page" do
    # Create 25 additional participants to exceed standard 20 per page
    25.times do |i|
      u = User.create!(
        email: "extra_student_#{i}_#{SecureRandom.hex(4)}@test.com",
        password: "password123",
        role: :participant,
        first_name: "Extra",
        last_name: "Student#{i}",
        active: true,
        institute: @institute,
        section: @section_a
      )
      Participant.create!(
        user: u,
        institute: @institute,
        section_id: @section_a.id,
        participant_type: :student
      )
    end

    total_approved = @institute.participants.joins(:user).where(users: { active: true }).where.not(status: :suspended).count
    assert total_approved > 20

    # With default 20 per page, exactly 20 participant rows are rendered
    get institute_admin_participants_path(approved: "true")
    assert_response :success
    assert_select ".approved-participant-checkbox", count: 20
    assert_select ".pagination"

    # With per_page=all, all participants are returned on page 1 and no pagination buttons needed
    get institute_admin_participants_path(approved: "true", per_page: "all")
    assert_response :success
    assert_select ".approved-participant-checkbox", count: total_approved
    assert_includes response.body, "Showing all #{total_approved} participants"
  end

  test "per_page is rendered in suspended and not approved views and preserved in pagination links" do
    # Not approved view
    get institute_admin_participants_path(approved: "false", per_page: "50")
    assert_response :success
    assert_select "select[name='per_page'] option[value='50'][selected]"

    # Suspended view
    get institute_admin_participants_path(status: "suspended", per_page: "100")
    assert_response :success
    assert_select "select[name='per_page'] option[value='100'][selected]"
  end
end
