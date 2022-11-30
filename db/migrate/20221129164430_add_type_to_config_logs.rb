class AddTypeToConfigLogs < ActiveRecord::Migration[6.0]
  def change
    add_column :config_logs, :type, :string
  end
end
