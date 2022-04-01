class AddMonitorOverrideToChangeRequests < ActiveRecord::Migration[6.0]
  def change
    add_column :change_requests, :monitor_override_hours, :integer
  end
end
