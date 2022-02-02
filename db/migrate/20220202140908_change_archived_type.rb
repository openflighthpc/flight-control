class ChangeArchivedType < ActiveRecord::Migration[6.0]
  def change
    remove_column :projects, :archived, :boolean, default: false
    add_column :projects, :archived_date, :date
  end
end
