class Section < ApplicationRecord
  belongs_to :institute
  has_many :users, dependent: :restrict_with_error
  has_many :participants, -> { kept }, through: :users
  has_many :all_participants, through: :users, source: :participant
  has_many :section_training_programs, class_name: "TrainingProgram", foreign_key: "section_id", dependent: :destroy
  has_many :training_program_sections, dependent: :destroy
  has_many :training_programs, through: :training_program_sections

  enum :status, { active: 0, inactive: 1 }, default: :active

  validates :name, presence: true
  validates :code, presence: true, uniqueness: { scope: :institute_id }
  validates :capacity, presence: true, numericality: { greater_than: 0 }

  scope :active, -> { where(status: :active) }

  def participants_count
    participants.count
  end

  before_destroy :check_for_participants

  private

  def check_for_participants
    if participants.exists?
      errors.add(:base, "Cannot delete section because it has participants")
      throw :abort
    end
  end
end
