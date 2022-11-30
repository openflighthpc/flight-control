# frozen_string_literal: true

class SetConfigLogType < ActiveRecord::Migration[6.0]
  def up
    ConfigLog.where(type: nil).find_each { |c| c.update(type: "MonitorConfigLog") }
  end

  def down
  end
end
