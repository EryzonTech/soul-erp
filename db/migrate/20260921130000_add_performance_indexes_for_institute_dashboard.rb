class AddPerformanceIndexesForInstituteDashboard < ActiveRecord::Migration[8.0]
  def change
    add_index :assignment_response_logs, [ :institute_id, :response_date ],
              name: "index_assignment_response_logs_on_institute_and_date",
              if_not_exists: true

    add_index :assignment_responses, [ :response_date, :participant_id ],
              name: "index_assignment_responses_on_date_and_participant",
              if_not_exists: true

    add_index :participants, [ :institute_id, :participant_type ],
              name: "index_participants_on_institute_and_type",
              if_not_exists: true

    add_index :training_programs, [ :institute_id, :status ],
              name: "index_training_programs_on_institute_and_status",
              if_not_exists: true
  end
end
