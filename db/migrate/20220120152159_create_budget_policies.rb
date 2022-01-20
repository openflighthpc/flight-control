class CreateBudgetPolicies < ActiveRecord::Migration[6.0]
  def change
    create_table :budget_policies do |t|
      t.references :project, index: true
      t.string :cycle_interval
      t.integer :days
      t.string :spend_profile
      t.integer :cycle_limit
      t.date :effective_at
      t.timestamps
    end
  end
end
