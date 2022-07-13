class CreateInstanceTypeDetails < ActiveRecord::Migration[6.0]
  def change
    create_table :instance_type_details do |t|
      t.string  :instance_type
      t.string  :region
      t.decimal :price_per_hour
      t.integer :cpu
      t.integer :gpu
      t.decimal :mem
      t.string  :currency

      t.timestamps
    end

    add_index :instance_type_details, [:instance_type, :region], unique: true
  end
end
