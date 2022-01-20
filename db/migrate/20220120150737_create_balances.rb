class CreateBalances < ActiveRecord::Migration[6.0]
  def change
    create_table :balances do |t|
      t.references :project, index: true
      t.integer :amount
      t.date :effective_at
      t.timestamps
    end
  end
end
