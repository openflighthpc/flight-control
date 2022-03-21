class CreateUserRoles < ActiveRecord::Migration[6.0]
  def change
    create_table :user_roles do |t|
      t.references :user,     null: false, foreign_key: true
      t.references :project,  null: false, foreign_key: true
      t.string :role,         null: false, limit: 64

      t.timestamps
    end

    add_index :user_roles, :role
    add_index :user_roles, [:role, :project_id, :user_id], unique: true
  end
end
