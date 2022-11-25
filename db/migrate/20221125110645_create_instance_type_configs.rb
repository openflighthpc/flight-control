class CreateInstanceTypeConfigs < ActiveRecord::Migration[6.0]
  def change
    create_table :instance_type_configs do |t|
      t.references :compute_group_config, index: true
      t.references :project, index: true
      t.string :instance_type
      t.integer :priority
      t.integer :limit

      t.timestamps
    end
  end
end
