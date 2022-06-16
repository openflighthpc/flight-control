class RenameBalances < ActiveRecord::Migration[6.0]
  def change
    rename_table :balances, :hub_balances
    rename_column :hub_balances, :effective_at, :date
    add_index :hub_balances, :date
  end
end
