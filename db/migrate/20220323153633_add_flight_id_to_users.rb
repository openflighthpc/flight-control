class AddFlightIdToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :flight_id, :uuid, index: true
  end
end
