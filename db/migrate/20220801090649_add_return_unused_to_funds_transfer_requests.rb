class AddReturnUnusedToFundsTransferRequests < ActiveRecord::Migration[6.0]
  def change
    add_column :funds_transfer_requests, :return_unused, :boolean, default: false
  end
end
