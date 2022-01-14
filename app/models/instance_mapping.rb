class InstanceMapping < ApplicationRecord
  validates :instance_type, presence: true, uniqueness: true
  validates :customer_facing_type, presence: true, uniqueness: { scope: :platform }
  validates :platform,
    presence: true,
    inclusion: {
      in: %w(aws azure),
      message: "%{value} is not a valid platform"
    }
end
