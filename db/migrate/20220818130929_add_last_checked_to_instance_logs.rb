class AddLastCheckedToInstanceLogs < ActiveRecord::Migration[6.0]
  def change
    add_column :instance_logs, :last_checked, :datetime
  end
end

