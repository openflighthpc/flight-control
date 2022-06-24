class Budget < ApplicationRecord
  belongs_to :project
  validates :amount, numericality: { greater_than_or_equal_to: 0 }
  validates :effective_at, presence: true
  default_scope { order(:effective_at, :created_at) }

  validate :expiry_not_before_effective, if: -> { expiry_date != nil }

  private

  # We may have continuous project budgets that are expired on the same
  # day they are effective (e.g. if new c.u.s retrieved from the department
  # multiple times on one day).
  def expiry_not_before_effective
    if expiry_date < effective_at
      errors.add(:expiry_date, "must be after on same day as effective at date")
    end
  end
end
