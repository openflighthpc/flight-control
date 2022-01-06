class CreateInstanceLogs < ActiveRecord::Migration[6.0]
  def change
    create_table :instance_logs do |t|
      t.references :project, index: true
      t.string :instance_type
      t.string :instance_name
      t.text :instance_id
      t.string :platform
      t.string :region
      t.string :compute_group
      t.string :status
      t.date :date, index: true
      t.timestamps
    end
  end
end
