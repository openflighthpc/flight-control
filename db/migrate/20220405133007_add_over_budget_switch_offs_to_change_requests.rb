class AddOverBudgetSwitchOffsToChangeRequests < ActiveRecord::Migration[6.0]
  def change
    add_column :change_requests, :over_budget_switch_offs, :boolean, default: false
  end
end
