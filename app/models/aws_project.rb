require_relative 'project'
require_relative '../services/aws_instance_recorder'
require_relative '../services/aws_costs_recorder'
require_relative '../services/aws_instance_details_recorder'
require_relative '../services/aws_instance_manager'
require_relative '../services/aws_monitor'

class AwsProject < Project
  alias_attribute :access_key_ident, :security_id
  alias_attribute :key, :security_key
  validates :regions, presence: true
  validates :filter_level,
    presence: true,
    inclusion: {
      in: %w(tag account),
      message: "%{value} is not a valid filter level. Must be tag or account."
    }
  validate :project_tag_if_tag_filter
  validate :regions_not_empty

  default_scope { where(platform: "aws") }

  def describe_regions
    regions.join(", ")
  end

  def instance_recorder
    @instance_recorder ||= AwsInstanceRecorder.new(self)
  end

  def instance_manager
    @instance_manager ||= AwsInstanceManager.new(self)
  end

  def costs_recorder
    @costs_recorder ||= AwsCostsRecorder.new(self)
  end

  def monitor
    @monitor ||= AwsMonitor.new(self)
  end

  # Instance type prices and sizes
  def instance_details_recorder
    @instance_details_recorder ||= AwsInstanceDetailsRecorder.new(self)
  end

  # How instances must be grouped for SDK queries, e.g. switch ons/offs
  def instance_grouping
    "region"
  end

  private

  def project_tag_if_tag_filter
    errors.add(:project_tag, "Must be defined if filter level is tag") if filter_level == "tag" && !project_tag
  end

  def regions_not_empty
    errors.add(:regions, "Must contain at least one value") if regions.empty?
  end
end
