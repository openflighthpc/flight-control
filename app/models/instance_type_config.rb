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

  def customer_facing_type
    @customer_facing_name ||= InstanceMapping.instance_mappings[project.platform][instance_type] || "Compute (Other)"
  end

  def group_priority
    @group_priority ||= compute_group_config.priority
  end

  def weighted_priority
    priority * compute_group_config.priority
  end

  def mem
    InstanceTypeDetail.find_by(instance_type: instance_type, region: compute_group_config.region)&.mem || 0
  end

  def <=>(other)
    [self.weighted_priority, self.group_priority, self.mem.to_f] <=> [other.weighted_priority, other.group_priority, other.mem.to_f]
  end
end
