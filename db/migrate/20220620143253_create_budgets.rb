class CreateBudgets < ActiveRecord::Migration[6.0]
  def change
    create_table :budgets do |t|
      t.references :project, index: true
      t.bigint :amount
      t.date :effective_at, index: true
      t.date :expiry_date

      t.timestamps
    end
  end
end
