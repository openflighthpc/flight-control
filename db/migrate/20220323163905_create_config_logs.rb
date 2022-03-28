class CreateConfigLogs < ActiveRecord::Migration[6.0]
  def change
    create_table :config_logs do |t|
      t.references :project, index: true
      t.references :user, index: true
      t.references :change_request, index: true
      t.json :config_changes
      t.boolean :automated
      t.date :date
      t.timestamps
    end
  end
end
