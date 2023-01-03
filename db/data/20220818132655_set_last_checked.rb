# frozen_string_literal: true

class SetLastChecked < ActiveRecord::Migration[6.0]
  def up
    InstanceLog.find_each do |log|
      log.last_checked = log.updated_at
      log.last_status_change = log.updated_at
      log.save!
    end
  end

  def down
    InstanceLog.update_all(last_checked: nil, last_status_change: nil)
  end
end
