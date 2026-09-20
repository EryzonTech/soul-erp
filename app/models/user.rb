class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :trackable,
         authentication_keys: [ :login ]

  # Skip password validation when password is not being updated
  def password_required?
    return false if persisted? && password.blank? && password_confirmation.blank?
    super
  end

  # Make email optional (Devise's :validatable requires this override)
  def email_required?
    false
  end

  belongs_to :institute, optional: true
  has_one :trainer, dependent: :destroy
  has_one :participant, dependent: :destroy
  has_one :guardian, dependent: :destroy
  belongs_to :section, optional: true
  has_many :training_programs, foreign_key: :trainer_id

  enum :role, {
    master_admin: 0,
    institute_admin: 1,
    trainer: 2,
    participant: 3,
    guardian: 4
  }, default: :participant

  validates :username, uniqueness: true, allow_nil: true
  validates :email, uniqueness: { case_sensitive: false }, allow_blank: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP, message: "is not a valid email address" }, allow_nil: true
  validates :first_name, presence: true, length: { maximum: 50 }, if: :requires_first_name?
  validates :phone, format: { with: /\A\d{10}\z/, message: "must be a valid 10-digit number" },
                   allow_blank: true,
                   uniqueness: { case_sensitive: false }
  validate :email_or_phone_required, if: :participant?

  # Nilify blank email to avoid uniqueness conflicts on empty strings
  before_validation :nilify_blank_email

  attr_accessor :login

  # Scopes
  scope :institute_admin, -> { where(role: :institute_admin) }
  scope :active, -> { where(active: true) }
  scope :trainer, -> { where(role: :trainer) }
  scope :participant, -> { where(role: :participant) }
  scope :guardian, -> { where(role: :guardian) }
  scope :view_only_admin, -> { where(role: :institute_admin, view_only: true) }

  accepts_nested_attributes_for :participant
  accepts_nested_attributes_for :trainer

  def login
    @login || username || email || phone
  end

  # Allow login with username, email or phone
  def self.find_for_database_authentication(warden_conditions)
    conditions = warden_conditions.dup
    if (login = conditions.delete(:login))
      where(conditions.to_h).where([ "lower(username) = :value OR lower(email) = :value OR phone = :value",
        { value: login.downcase } ]).first
    elsif conditions.has_key?(:username) || conditions.has_key?(:email) || conditions.has_key?(:phone)
      where(conditions.to_h).first
    end
  end

  def active_for_authentication?
    super && active?
  end

  # This provides the reason shown to users when they can't log in
  def inactive_message
    active? ? super : :inactive
  end

  def full_name
    if first_name.present? && last_name.present?
      "#{first_name} #{last_name}".strip
    elsif first_name.present?
      first_name
    elsif last_name.present?
      last_name
    else
      email
    end
  end

  # Alias for compatibility
  def name
    full_name
  end

  def institute_admin?
    role == "institute_admin"
  end

  # Returns true when this user is an institute admin with view-only privilege.
  # Master admins impersonating an institute never inherit the view-only restriction.
  def view_only_admin?
    institute_admin? && view_only?
  end

  def trainer?
    role == "trainer"
  end

  def participant?
    role == "participant"
  end

  private

  def requires_first_name?
    participant? || trainer?
  end

  def nilify_blank_email
    self.email = nil if email.blank?
  end

  def email_or_phone_required
    phone_number = participant&.phone_number
    if email.blank? && phone_number.blank?
      errors.add(:base, "Either email or phone number must be provided")
      errors.add(:email, "or phone number must be provided") if errors[:email].empty?
    end
  end
end
