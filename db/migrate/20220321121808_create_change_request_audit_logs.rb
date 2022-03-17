class CreateChangeRequestAuditLogs < ActiveRecord::Migration[6.0]
  def change
    create_table :change_request_audit_logs do |t|
      t.references :project, index: true
      t.references :change_request, index: true
      t.json :updates
      t.date :date
      t.timestamps
    end
  end
end
