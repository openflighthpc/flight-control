class AddArchivedToConfigs < ActiveRecord::Migration[6.0]
  def change
    add_column :compute_group_configs, :archived_date, :date
    add_column :instance_type_configs, :archived_date, :date
  end
end
