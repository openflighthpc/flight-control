class SetRiskCosts < ActiveRecord::Migration[6.0]
  class CostLog < ApplicationRecord
    after_initialize :calculate_risk_cost

    private

    def calculate_risk_cost
      return if self.risk_cost

      usd_gbp_conversion = Rails.application.config.usd_gbp_conversion || 0.77
      gbp_compute_conversion = Rails.application.config.gbp_compute_conversion || 12.5
      at_risk_conversion = Rails.application.config.at_risk_conversion || 1.25

      gbp_cost = currency == "USD" ? (self.cost.to_f * usd_gbp_conversion) : self.cost.to_f
      compute_cost = gbp_cost * gbp_compute_conversion

      cost = (compute_cost.to_f * at_risk_conversion)
      self.risk_cost = (scope == "total") ? cost.ceil : cost.round
    end
  end

  def up
    CostLog.all.each do |log|
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
