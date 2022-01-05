class CreateProjects < ActiveRecord::Migration[6.0]
  def change
    create_table :projects do |t|
      t.string :name
      t.string :type
      t.string :platform
      t.string :filter_level
      t.date :start_date
      t.date :end_date
      t.boolean :visualiser
      t.boolean :archived
      t.string :slack_channel
      t.string :security_id
      t.string :security_key
      t.text :regions
      t.text :resource_groups
      t.string :account_id
      t.string :project_tag
      t.string :subscription_id
      t.string :tenant_id
      t.text :bearer_token
      t.text :bearer_expiry
      t.float :utilisation_threshold
      t.datetime :override_monitor_until
      t.boolean :monitor_active
      t.timestamps
    end
  end
end
