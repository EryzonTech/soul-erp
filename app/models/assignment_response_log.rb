class AssignmentResponseLog < ApplicationRecord
  belongs_to :institute
  belongs_to :participant
  belongs_to :assignment

  validates :response_date, presence: true
  validates :assignment_response_ids, presence: true

  # Method to create a log entry for assignment responses
  def self.log_responses(participant:, assignment:, response_ids:, response_date:)
    create!(
      institute: participant.institute,
      participant: participant,
      assignment: assignment,
      response_date: response_date,
      assignment_response_ids: Array(response_ids)
    )
  end

  def responses
    AssignmentResponse.where(id: assignment_response_ids)
  end
end
