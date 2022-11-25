class InstanceTypeConfig < ApplicationRecord
  belongs_to :project
  belongs_to :compute_group_config
  default_scope { order(:priority) }

  validates :limit, :priority, :instance_type, presence: true
  validates :priority, numericality: { greater_than_or_equal_to: 1 }
  validates :priority, numericality: { greater_than_or_equal_to: 0 }

  def project
    compute_group_config.project
  end

  def customer_facing_name
    @customer_facing_name ||= InstanceMapping.instance_mappings[project.platform][instance_type]
  end
end
