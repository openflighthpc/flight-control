class AddFlightHubIdToProjects < ActiveRecord::Migration[6.0]
  def change
    add_column :projects, :flight_hub_id, :bigint
  end
end
