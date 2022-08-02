# frozen_string_literal: true

class EnforceMonthlyStartDate < ActiveRecord::Migration[6.0]
  class Project < ActiveRecord::Base
    has_many :budget_policies
    self.inheritance_column = nil

    def monthly?
      budget_policies.where("effective_at <= ?", Date.current).last&.cycle_interval == "monthly"
    end
  end

  def up
    Project.all.each do |project|
      if project.monthly? && project.start_date.day != 1
        project.start_date = project.start_date.beginning_of_month
        project.save!
      end
    end
  end

  def down
  end
end
