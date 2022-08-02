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
  validates :effective_at, presence: true
  default_scope { order(:effective_at, :created_at) }

  after_save { adjust_project_start_date_if_required }
   
  def cycle_length
    case cycle_interval
    when "monthly"
      "1 month"
    when "weekly"
      "1 week"
    when "custom"
      "#{days} days"
    end
  end

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

  def adjust_project_start_date_if_required
    if cycle_interval == "monthly" && project.start_date.day != 1
      project.start_date = project.start_date.beginning_of_month
      project.save!
    end
  end
end
