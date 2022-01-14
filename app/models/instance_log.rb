class InstanceLog < ApplicationRecord
  belongs_to :project
  validates :instance_type, :instance_name, :instance_id,
            :region, :status, :date, presence: true
  validates :platform,
    presence: true,
    inclusion: {
      in: %w(aws azure),
      message: "%{value} is not a valid platform"
    }
end
