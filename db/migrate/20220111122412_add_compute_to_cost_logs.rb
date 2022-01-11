class AddComputeToCostLogs < ActiveRecord::Migration[6.0]
  def change
    add_column :cost_logs, :compute, :boolean, default: false
  end
end
