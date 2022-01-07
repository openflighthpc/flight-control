class CreateCostLogs < ActiveRecord::Migration[6.0]
  def change
    create_table :cost_logs do |t|
      t.references :project, index: true
      t.decimal :cost
      t.string :scope
      t.date :date, index: true
      t.timestamps
    end
  end
end
