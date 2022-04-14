class AddSkipDatesToChangeRequests < ActiveRecord::Migration[6.0]
  def change
    add_column :change_requests, :skip_dates, :string, array: true, default: []
  end
end
