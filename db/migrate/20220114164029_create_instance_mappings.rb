class CreateInstanceMappings < ActiveRecord::Migration[6.0]
  def change
    create_table :instance_mappings do |t|
      t.string :platform
      t.string :instance_type
      t.string :customer_facing_type
    end
  end
end
