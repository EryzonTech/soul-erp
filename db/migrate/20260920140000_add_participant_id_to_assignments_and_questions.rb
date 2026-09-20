class AddParticipantIdToAssignmentsAndQuestions < ActiveRecord::Migration[8.0]
  def change
    add_reference :assignments, :participant, foreign_key: true, null: true
    add_reference :questions, :participant, foreign_key: true, null: true
  end
end
