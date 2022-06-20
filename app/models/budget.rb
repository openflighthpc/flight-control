class Budget < ApplicationRecord
  belongs_to :project
  validates :amount, numericality: { greater_than_or_equal_to: 0 }
  validates :effective_at, presence: true
  default_scope { order(:effective_at, :created_at) }

  validate :expiry_after_effective, if: -> { expiry_date != nil }

  private

  def expiry_after_effective
    if expiry_date <= effective_at
      errors.add(:expiry_date, "must be after effective at date")
    end
  end
end
