class CreateComputeGroupConfigs < ActiveRecord::Migration[6.0]
  def change
    create_table :compute_group_configs do |t|
      t.references :project, index: true
      t.string :name
      t.string :region
      t.string :colour
      t.string :storage_colour
      t.integer :priority

      t.timestamps
    end
  end
end
