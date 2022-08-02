class AddPlatformToInstanceTypeDetails < ActiveRecord::Migration[6.0]
  def change
    add_column :instance_type_details, :platform, :string
    add_index :instance_type_details, :platform
  end
end
