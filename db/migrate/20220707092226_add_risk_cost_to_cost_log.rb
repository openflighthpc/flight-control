class AddRiskCostToCostLog < ActiveRecord::Migration[6.0]
  def change
    add_column :cost_logs, :risk_cost, :integer
  end
end
