class Institute < ApplicationRecord
  # Logo attachment
  has_one_attached :logo

  # Associations
  has_many :users, dependent: :destroy
  has_many :sections, dependent: :destroy
  has_many :training_programs, dependent: :destroy
  has_many :trainers, dependent: :destroy
  has_many :participants, -> { kept }, dependent: :destroy
  has_many :all_participants, class_name: "Participant", dependent: :destroy
  has_many :trainer_profiles
  has_many :participant_profiles
  has_many :questions, -> { order(position: :asc, created_at: :asc, id: :asc) }, dependent: :destroy
  has_many :question_categories, dependent: :destroy
  has_many :question_sets, dependent: :destroy
  has_many :assignments, dependent: :destroy
  has_many :assignment_responses, through: :participants
  has_many :certificate_configurations, dependent: :destroy
  has_many :individual_certificates, dependent: :destroy

  # Validations
  validates :name, presence: true
  validates :code, presence: true, uniqueness: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :contact_number, presence: true
  validates :institution_type, presence: true, inclusion: { in: [ "School", "Hospital", "Business firm", "Other" ] }

  # Scopes
  scope :active, -> { where(active: true) }

  def active_trainers_count
    trainers.joins(:user).where(users: { active: true }).count
  end

  def active_participants_count
    participants.joins(:user).where(users: { active: true }).count
  end

  # Add a scope to get participants with their users
  def active_participants
    participants.includes(:user).active
  end

  # Helper method to find a certificate
  def find_certificate(id)
    individual_certificates.find(id)
  end
end
