class Participant < ApplicationRecord
  belongs_to :user
  belongs_to :institute
  has_one :guardian, dependent: :destroy

  # Many-to-many: a guardian participant can be linked to multiple students
  has_many :guardian_student_links, foreign_key: :guardian_participant_id, dependent: :destroy
  has_many :student_participants, through: :guardian_student_links, source: :student_participant

  # Inverse: a student participant can have multiple guardians
  has_many :student_guardian_links, class_name: "GuardianStudentLink", foreign_key: :student_participant_id, dependent: :destroy
  has_many :guardian_participants, through: :student_guardian_links, source: :guardian_participant

  # Kept for backward compatibility — returns the first linked student (if any)
  belongs_to :guardian_for_participant, class_name: "Participant", optional: true
  has_many :guardians, class_name: "Participant", foreign_key: "guardian_for_participant_id"

  has_many :assignment_responses, dependent: :destroy
  has_many :assignment_response_logs, dependent: :destroy

  # Get section through user
  has_one :section, through: :user

  # Update training program associations with dependent: :nullify
  has_many :individual_training_programs, class_name: "TrainingProgram", foreign_key: "participant_id", dependent: :nullify
  has_many :section_training_programs, through: :section, source: :training_programs

  # Add the training_program_participants association with dependent: :destroy
  has_many :training_program_participants, dependent: :destroy
  has_many :training_programs, through: :training_program_participants

  # Add these associations with dependent: :destroy
  has_many :assignment_participants, dependent: :destroy
  has_many :assignments, through: :assignment_participants
  has_many :custom_assignments, class_name: "Assignment", foreign_key: "participant_id", dependent: :destroy
  has_many :custom_questions, class_name: "Question", foreign_key: "participant_id", dependent: :destroy

  # Enum for participant type
  enum :participant_type, {
    student: "student",
    guardian: "guardian",
    employee: "employee"
  }, default: :student

  # Phone number: required only if user has no email
  validates :phone_number, presence: { message: "is required when email is not provided" },
                           if: :phone_required?
  validates :phone_number, format: { with: /\A\d{10}\z/, message: "must be a valid 10-digit number" },
                           allow_blank: true
  validates :institute_id, presence: true
  validates :section_id, presence: true
  validates :user, presence: true
  validates :participant_type, presence: true


  # Add callbacks for both create and update
  after_create :sync_user_associations
  after_save :sync_user_associations

  enum :status, {
    active: 0,
    inactive: 1,
    on_leave: 2,
    graduated: 3,
    dropped: 4
  }, default: :active

  accepts_nested_attributes_for :guardian

  scope :active, -> { where(status: :active) }
  scope :with_user, -> { includes(:user) }
  scope :ordered_by_name, -> {
    joins(:user).order(Arel.sql("LOWER(COALESCE(users.first_name, '')) ASC, LOWER(COALESCE(users.last_name, '')) ASC, LOWER(COALESCE(users.email, '')) ASC"))
  }

  delegate :full_name, :email, to: :user, allow_nil: true

  # Helper method to get all training programs (both individual and section)
  def all_training_programs
    TrainingProgram.where(id: individual_training_programs.pluck(:id) + training_programs.pluck(:id) + section_training_programs.pluck(:id)).distinct
  end

  # Methods to get training programs by status
  def completed_programs
    all_training_programs.completed
  end

  def ongoing_programs
    all_training_programs.ongoing
  end

  # Helper method to get all responses (alias for assignment_responses)
  def responses
    assignment_responses
  end

  def assignments_for_date(date)
    individual_assignments = Assignment
      .joins(:assignment_participants)
      .where(assignment_participants: { participant_id: id })
      .where("DATE(assignments.start_date) <= ? AND DATE(assignments.end_date) >= ?", date, date)

    section_assignments = Assignment
      .joins(:assignment_sections)
      .where(assignment_sections: { section_id: section_id })
      .where("DATE(assignments.start_date) <= ? AND DATE(assignments.end_date) >= ?", date, date)

    Assignment.where(id: individual_assignments)
      .or(Assignment.where(id: section_assignments))
      .distinct
  end

  def assignments_for_date_range(start_date, end_date)
    individual_assignments = Assignment
      .joins(:assignment_participants)
      .where(assignment_participants: { participant_id: id })
      .where("DATE(assignments.start_date) <= ? AND DATE(assignments.end_date) >= ?", end_date, start_date)

    section_assignments = Assignment
      .joins(:assignment_sections)
      .where(assignment_sections: { section_id: section_id })
      .where("DATE(assignments.start_date) <= ? AND DATE(assignments.end_date) >= ?", end_date, start_date)

    Assignment.where(id: individual_assignments)
      .or(Assignment.where(id: section_assignments))
      .distinct
  end

  # Helper methods to check participant type
  def student?
    self[:participant_type] == "student" || self[:participant_type].nil?
  end

  def guardian?
    self[:participant_type] == "guardian"
  end

  def employee?
    self[:participant_type] == "employee"
  end

  private

  def phone_required?
    user&.email.blank?
  end

  def sync_user_associations
    return unless user.present?

    # Only update the user's institute_id if it's different
    if user.institute_id != institute_id
      user.update_column(:institute_id, institute_id)
    end

    # Get the section_id from the user if it's not set on the participant
    if section_id.nil? && user.section_id.present?
      update_column(:section_id, user.section_id)
    # Update the user's section_id if it's different and section_id is present on the participant
    elsif section_id.present? && user.section_id != section_id
      user.update_column(:section_id, section_id)
    end
  end
end
