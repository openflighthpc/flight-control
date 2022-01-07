class InstanceLog < ApplicationRecord
  belongs_to :project
  validates :instance_type, :instance_name, :instance_id,
           :platform, :region, :status, :date, presence: true
end
