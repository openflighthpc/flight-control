class RenameBalances < ActiveRecord::Migration[6.0]
  def change
    rename_table :balances, :hub_balances
    add_index :hub_balances, :effective_at
  end
end
