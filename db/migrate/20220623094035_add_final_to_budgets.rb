class AddFinalToBudgets < ActiveRecord::Migration[6.0]
  def change
    add_column :budgets, :final, :boolean, default: false
  end
end
