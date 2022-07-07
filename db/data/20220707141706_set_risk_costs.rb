class SetRiskCosts < ActiveRecord::Migration[6.0]
  class CostLog < ApplicationRecord
    def up
      CostLog.all.each do |log|
        log.calculate_risk_cost
        log.save!
      end
    end

    def down
      CostLog.all.each do |log|
        log.risk_cost = nil
        log.save!
      end
    end
  end
end
