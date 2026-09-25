require "test_helper"

class ParticipantTest < ActiveSupport::TestCase
  setup do
    @institute = Institute.create!(
      name: "Test Institute",
      code: "INST#{SecureRandom.hex(3)}",
      email: "inst_#{SecureRandom.hex(3)}@example.com",
      contact_number: "9876543210",
      institution_type: "School"
    )
    @section = Section.create!(
      name: "Section A",
      code: "SEC-A-#{SecureRandom.hex(2)}",
      capacity: 30,
      institute: @institute
    )
    @user = User.create!(
      email: "user_#{SecureRandom.hex(3)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: :participant,
      first_name: "John",
      last_name: "Doe",
      institute: @institute,
      section: @section
    )
  end

  test "is valid without date_of_birth" do
    participant = Participant.new(
      user: @user,
      institute: @institute,
      section_id: @section.id,
      participant_type: :student,
      date_of_birth: nil
    )
    assert participant.valid?, "Participant should be valid without date_of_birth: #{participant.errors.full_messages}"
  end

  test "is valid with date_of_birth" do
    participant = Participant.new(
      user: @user,
      institute: @institute,
      section_id: @section.id,
      participant_type: :student,
      date_of_birth: Date.new(2005, 5, 15)
    )
    assert participant.valid?, "Participant should be valid with date_of_birth"
  end

  test "soft_delete! sets deleted_at on participant and deactivates associated user" do
    participant = Participant.create!(
      user: @user,
      institute: @institute,
      section_id: @section.id,
      participant_type: :student
    )

    assert_not participant.soft_deleted?
    assert @user.active?

    participant.soft_delete!

    assert participant.soft_deleted?
    assert participant.deleted?
    assert_not_nil participant.deleted_at

    @user.reload
    assert_not @user.active?
    assert_not_nil @user.deleted_at
    assert @user.deleted?

    # Filtered from kept and institute participants
    assert_nil @institute.participants.find_by(id: participant.id)
    assert_not_includes Participant.kept, participant
    assert_includes Participant.deleted, participant

    # Preserved in database for belongs_to associations
    assert_equal participant, Participant.find_by(id: participant.id)

    # Restore
    participant.restore!
    assert_not participant.soft_deleted?
    assert_nil participant.deleted_at
    assert_includes @institute.participants, participant
    assert_includes Participant.kept, participant
  end
end
