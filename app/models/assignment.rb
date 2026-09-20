class Assignment < ApplicationRecord
  attr_accessor :skip_association_validation

  belongs_to :institute
  belongs_to :participant, optional: true
  belongs_to :section, optional: true
  belongs_to :question_category, optional: true

  has_many :assignment_sections, dependent: :destroy
  has_many :sections, through: :assignment_sections

  has_many :assignment_participants, dependent: :destroy
  has_many :participants, through: :assignment_participants

  has_many :assignment_questions, dependent: :destroy
  has_many :questions, through: :assignment_questions

  has_many :assignment_question_sets, dependent: :destroy
  has_many :question_sets, through: :assignment_question_sets

  has_many :assignment_responses, dependent: :destroy
  has_many :assignment_response_logs, dependent: :destroy
  has_many :individual_certificates, dependent: :restrict_with_error

  before_destroy :check_associations_before_destroy, prepend: true

  validates :title, presence: true
  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :assignment_type, presence: true, inclusion: { in: [ "individual", "section" ] }

  validate :end_date_after_start_date
  validate :validate_associations

  accepts_nested_attributes_for :assignment_sections, allow_destroy: true
  accepts_nested_attributes_for :assignment_participants, allow_destroy: true
  accepts_nested_attributes_for :assignment_questions, allow_destroy: true
  accepts_nested_attributes_for :assignment_question_sets, allow_destroy: true

  scope :active, -> { where(active: true) }
  scope :custom, -> { where.not(participant_id: nil) }
  scope :institute_assigned, -> { where(participant_id: nil) }
  scope :current, -> { active.where("start_date <= ? AND end_date >= ?", Time.current, Time.current) }
  scope :upcoming, -> { active.where("start_date > ?", Time.current) }
  scope :past, -> { active.where("end_date < ?", Time.current) }
  scope :for_date, ->(date) {
    where("DATE(start_date) <= :date AND DATE(end_date) >= :date", date: date)
  }

  scope :for_participant, ->(participant) {
    select("assignments.*")
      .active
      .joins("LEFT JOIN assignment_participants ON assignments.id = assignment_participants.assignment_id")
      .joins("LEFT JOIN assignment_sections ON assignments.id = assignment_sections.assignment_id")
      .where("assignment_participants.participant_id = :participant_id OR assignment_sections.section_id = :section_id",
        participant_id: participant.id,
        section_id: participant.section_id)
      .distinct
  }

  def self.permitted_attributes
    [
      :title, :description, :start_date, :end_date,
      :assignment_type, :section_id,
      section_ids: [], participant_ids: [],
      question_ids: [], question_set_ids: []
    ]
  end

  def available_for?(participant)
    return false unless active?
    return false if Date.current < start_date || Date.current > end_date

    if assignment_type == "individual"
      participants.include?(participant)
    else
      sections.include?(participant.section)
    end
  end

  def answered_by?(participant)
    questions_count = questions.count + question_sets.sum { |qs| qs.questions.count }
    assignment_responses.where(participant: participant).count == questions_count
  end

  def answered_by_on_date?(participant, selected_date)
    assignment_responses.exists?(
      participant: participant,
      response_date: selected_date
    )
  end

  def available_for_date?(participant, date)
    return false unless active?
    return false if date > Date.current # Can't do future dates
    return false if date < start_date || date > end_date
    return false if answered_by_on_date?(participant, date)
    return false if questions_grouped_by_bundle_for_date(date).empty?

    if assignment_type == "individual"
      participants.include?(participant)
    else
      sections.include?(participant.section)
    end
  end

  def latest_unanswered_date_for(participant)
    max_date = [end_date.to_date, Date.current].min
    min_date = start_date.to_date
    return nil if max_date < min_date

    (min_date..max_date).to_a.reverse.find do |d|
      available_for_date?(participant, d)
    end
  end

  def valid_dates_up_to_today
    max_date = [end_date.to_date, Date.current].min
    min_date = start_date.to_date
    return [] if max_date < min_date

    (min_date..max_date).to_a
  end

  def total_days
    (end_date.to_date - start_date.to_date).to_i + 1
  end

  def completed_days(participant)
    assignment_responses
      .where(participant: participant)
      .distinct
      .pluck("DATE(response_date)")
      .count
  end

  def completion_percentage(participant)
    ((completed_days(participant).to_f / total_days) * 100).round(2)
  end

  def days_remaining
    [ (end_date.to_date - Date.current).to_i + 1, 0 ].max
  end

  def missed_days(participant)
    return 0 if Date.current <= start_date

    expected_days = [ (Date.current - start_date.to_date).to_i + 1, total_days ].min
    expected_days - completed_days(participant)
  end

  def all_questions
    if assignment_questions.where.not(order_number: nil).any?
      questions.joins(:assignment_questions).order("assignment_questions.order_number ASC, questions.id ASC")
    else
      questions.order(position: :asc, created_at: :asc, id: :asc) +
      question_sets.includes(:questions).flat_map { |qs| qs.questions.order(position: :asc, created_at: :asc, id: :asc) }
    end
  end

  def questions_grouped_by_bundle
    assigned_aqs = assignment_questions.includes(question: :options).order(:order_number, :id).to_a
    return {} if assigned_aqs.empty?

    groups = {}

    if question_category.present?
      # Preserve Category Bundle Order
      bundles = question_category.question_bundles.order(:position)
      matched_aq_ids = Set.new

      bundles.each do |bundle|
        # 1. Questions assigned explicitly to this bundle via assignment_questions.bundle_name
        bundle_aqs = assigned_aqs.select { |aq| aq.bundle_name == bundle.name }
        if bundle_aqs.any?
          groups[bundle.name] = bundle_aqs.map(&:question).compact
          matched_aq_ids.merge(bundle_aqs.map(&:id))
        else
          # 2. Fallback for legacy assignments: check template items
          template_q_ids = bundle.question_bundle_items.pluck(:question_id)
          legacy_aqs = assigned_aqs.select { |aq| aq.bundle_name.blank? && template_q_ids.include?(aq.question_id) }
          if legacy_aqs.any?
            groups[bundle.name] = legacy_aqs.map(&:question).compact
            matched_aq_ids.merge(legacy_aqs.map(&:id))
          end
        end
      end

      # Collect any remaining assignment questions whose bundle_name wasn't matched above
      unmatched_aqs = assigned_aqs.reject { |aq| matched_aq_ids.include?(aq.id) }
      if unmatched_aqs.any?
        unmatched_aqs.group_by { |aq| aq.bundle_name.presence || "Other Questions" }.each do |b_name, aqs|
          groups[b_name] = aqs.map(&:question).compact
        end
      end
    else
      groups["Questions"] = assigned_aqs.map(&:question).compact
    end

    groups
  end

  def all_questions_for_date(selected_date)
    questions_grouped_by_bundle_for_date(selected_date).values.flatten
  end

  def questions_grouped_by_bundle_for_date(selected_date)
    return {} if selected_date.blank?
    target_date = selected_date.to_date
    start_d = start_date.to_date
    return {} if target_date < start_d

    day_number = (target_date - start_d).to_i + 1
    all_grouped = questions_grouped_by_bundle
    return {} if all_grouped.empty?

    active_groups = {}

    all_grouped.each do |group_name, group_questions|
      next if group_questions.empty?

      bundle = question_category&.question_bundles&.find_by(name: group_name)

      bundle_from = bundle&.from_day || 1
      bundle_to = bundle&.to_day || question_category&.duration_days || total_days

      bundle_is_active = (day_number >= bundle_from && day_number <= bundle_to)

      active_questions_in_bundle = group_questions.select do |q|
        q_from = q.from_day || 1
        q_to = q.to_day || question_category&.duration_days || total_days

        question_is_active = (day_number >= q_from && day_number <= q_to)
        bundle_is_active && question_is_active
      end

      if active_questions_in_bundle.any?
        active_groups[group_name] = active_questions_in_bundle
      end
    end

    active_groups
  end

  def edit_questions_grouped_by_bundle
    assigned_aqs = assignment_questions.includes(question: :options).order(:order_number, :id).to_a

    groups = {}

    if question_category.present?
      bundles = question_category.question_bundles.includes(:question_bundle_items).order(:position)

      bundles.each do |bundle|
        # 1. Explicitly assigned questions to this bundle name
        bundle_aqs = assigned_aqs.select { |aq| aq.bundle_name == bundle.name }
        if bundle_aqs.any?
          groups[bundle.name] = bundle_aqs.map(&:question).compact
        else
          # 2. Template questions for category bundle (only bundled questions considered)
          b_questions = bundle.question_bundle_items.sort_by(&:position).map(&:question).compact
          groups[bundle.name] = b_questions if b_questions.any?
        end
      end

      # Custom Questions pool: custom institute questions not belonging to this category
      if institute.present?
        inst_custom_questions = institute.questions.includes(:options)
                                         .where("question_category_id IS NULL OR question_category_id != ?", question_category.id)
                                         .order(position: :asc, created_at: :asc, id: :asc).to_a
        groups["Institution Custom Questions"] = inst_custom_questions if inst_custom_questions.any?
      end

      groups
    else
      assigned_q_ids = assigned_aqs.map(&:question_id)
      inst_q_ids = institute&.questions&.pluck(:id) || []
      all_available_ids = (assigned_q_ids + inst_q_ids).uniq
      all_q = Question.includes(:options).where(id: all_available_ids).order(position: :asc, created_at: :asc, id: :asc).to_a
      { "Institution Questions" => all_q }
    end
  end

  def status
    return "inactive" unless active?

    if Time.current < start_date
      "upcoming"
    elsif Time.current > end_date
      "completed"
    else
      "active"
    end
  end

  def custom?
    participant_id.present?
  end

  private

  def validate_associations
    if persisted? && !skip_association_validation
      q_count = assignment_questions.reject(&:marked_for_destruction?).size
      qs_count = assignment_question_sets.reject(&:marked_for_destruction?).size
      if q_count == 0 && qs_count == 0
        errors.add(:base, "Must have at least one question or question set")
      end

      if assignment_type == "section"
        sec_count = assignment_sections.reject(&:marked_for_destruction?).size
        if section_id.blank? && sections.empty? && sec_count == 0
          errors.add(:base, "Must select at least one section")
        end
      elsif assignment_type == "individual"
        part_count = assignment_participants.reject(&:marked_for_destruction?).size
        if participants.empty? && part_count == 0
          errors.add(:base, "Must select at least one participant")
        end
      end
    end
  end

  def end_date_after_start_date
    return if end_date.blank? || start_date.blank?
    if end_date < start_date
      errors.add(:end_date, "must be after start date")
    end
  end

  def check_associations_before_destroy
    if individual_certificates.exists?
      count = individual_certificates.count
      errors.add(:base, "Cannot delete assignment '#{title}' because #{count} #{'certificate'.pluralize(count)} #{count == 1 ? 'has' : 'have'} been generated for it.")
      throw :abort
    end
  end
end
