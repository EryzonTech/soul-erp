class AddDeletedAtToParticipantsAndUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :participants, :deleted_at, :datetime
    add_index :participants, :deleted_at

    add_column :users, :deleted_at, :datetime
    add_index :users, :deleted_at
  end
end
