class InstanceTypeConfig < ApplicationRecord
  belongs_to :project
  belongs_to :compute_group_config

  default_scope { order(:priority) }
  scope :active, -> { where("archived_date IS NULL OR archived_date > ?", Date.current) }

  validates :limit, :priority, presence: true
  validates :priority, numericality: { greater_than_or_equal_to: 1 }
  validates :priority, numericality: { greater_than_or_equal_to: 0 }
  validate :instance_type_uniqueness

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

  private

  def instance_type_uniqueness
    if archived_date.nil? && compute_group_config.instance_type_configs.active.where(instance_type: self.instance_type).where.not(id: self.id).exists?
      errors.add(:instance_type, "already used")
    end
  end
end
