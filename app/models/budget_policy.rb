require_relative 'project'

class BudgetPolicy < ApplicationRecord
  belongs_to :project
  validates :cycle_interval,
    presence: true,
    inclusion: {
      in: %w[monthly weekly custom],
      message: "%{value} is not a valid cycle interval"
    }
  validate :has_days_if_custom
  validates :spend_profile,
    presence: true,
    inclusion: {
      in: %w[fixed rolling continuous dynamic],
      message: "%{value} is not a valid spend profile"
    }
  validate :cycle_limit_if_fixed_or_rolling
  validates :effective_at, presence: true

  private

  def has_days_if_custom
    if cycle_interval == "custom" && (!days || days < 1)
      errors.add(:days, "Must set positive number of days if custom cycle interval")
    end
  end

  def cycle_limit_if_fixed_or_rolling
    if %w[fixed rolling].include?(spend_profile) && (!cycle_limit || cycle_limit < 0) 
      errors.add(:cycle_limit, "Must set cycle limit if fixed or rolling spend profile")
    end
  end
end
