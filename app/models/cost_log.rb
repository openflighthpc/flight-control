class CostLog < ApplicationRecord
  belongs_to :project
  validates :cost, :currency, :scope, :date, :risk_cost, presence: true
  validates :cost, :risk_cost, numericality: { greater_than_or_equal_to: 0 }
  default_scope { order(:date) }
  after_initialize :calculate_risk_cost

  def self.usd_gbp_conversion
    @@usd_gbp_conversion ||= Rails.application.config.usd_gbp_conversion || 0.77
  end

  def self.gbp_compute_conversion
     @@gbp_compute_conversion ||= Rails.application.config.gbp_compute_conversion || 12.5
  end

  def self.at_risk_conversion
    @@risk_conversion ||= Rails.application.config.at_risk_conversion || 1.25
  end

  def compute_cost
    gbp_cost = currency == "USD" ? (cost.to_f * CostLog.usd_gbp_conversion) : cost.to_f
    (gbp_cost * CostLog.gbp_compute_conversion)
  end

  private

  def calculate_risk_cost
    return if self.risk_cost
    cost = (compute_cost.to_f * CostLog.at_risk_conversion)
    self.risk_cost = (scope == "total") ? cost.ceil : cost.round
  end
end
