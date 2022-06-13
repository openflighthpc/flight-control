class CreateFundsTransferRequests < ActiveRecord::Migration[6.0]
  def change
    create_table :funds_transfer_requests do |t|
      t.references :project, null: false, foreign_key: true
      t.bigint :amount
      t.string :action
      t.string :status
      t.text :reason
      t.text :request_errors
      t.date :date

      t.timestamps
    end
  end
end
