class AddLastCheckedToInstanceLogs < ActiveRecord::Migration[6.0]
  def change
    add_column :instance_logs, :last_checked, :datetime
    add_column :instance_logs, :last_status_change, :datetime
  end
end

