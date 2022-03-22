class AddUserIds < ActiveRecord::Migration[6.0]
  def change
    add_reference :action_logs, :user, index: true, foreign_key: true
    add_reference :change_requests, :user, index: true, foreign_key: true
    add_reference :change_request_audit_logs, :user, index: true, foreign_key: true
  end
end
