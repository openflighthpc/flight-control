class CreateChangeRequests < ActiveRecord::Migration[6.0]
  def change
    create_table :change_requests do |t|
      t.references :project, index: true
      t.json :counts
      t.string :counts_criteria
      t.string :time
      t.date :date
      t.string :weekdays
      t.date :end_date
      t.string :description
      t.string :status
      t.string :type
      t.datetime :actioned_at
      t.timestamps
    end
  end
end
