class CreateActionLogs < ActiveRecord::Migration[6.0]
  def change
    create_table :action_logs do |t|
      t.references :project, index: true
      t.references :change_request, index: true
      t.boolean :automated, default: false
      t.text :instance_id
      t.string :action
      t.text :reason
      t.string :status
      t.date :date
      t.time :actioned_at
      t.timestamps
    end
  end
end
