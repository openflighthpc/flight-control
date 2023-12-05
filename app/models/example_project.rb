require_relative 'project'
require_relative '../services/example_instance_recorder'
require_relative '../services/example_costs_recorder'
require_relative '../services/example_instance_details_recorder'
require_relative '../services/example_instance_manager'
require_relative '../services/example_monitor'

class ExampleProject < Project
  validates :filter_level,
    presence: true,
    inclusion: {
      in: ["tag", "account"],
      message: "%{value} is not a valid filter level. Must be tag or account."
    }
  validate :project_tag_if_tag_filter

  default_scope { where(platform: "example") }

  def describe_regions
    regions.join(", ")
  end

  def instance_recorder
    @instance_recorder ||= ExampleInstanceRecorder.new(self)
  end

  def instance_manager
    @instance_manager ||= ExampleInstanceManager.new(self)
  end

  def costs_recorder
    @costs_recorder ||= ExampleCostsRecorder.new(self)
  end

  def monitor
    @monitor ||= ExampleMonitor.new(self)
  end

  # Instance type prices and sizes
  def instance_details_recorder
    @instance_details_recorder ||= ExampleInstanceDetailsRecorder.new(self)
  end

  # How instances must be grouped for SDK queries, e.g. switch ons/offs
  def instance_grouping
    "region"
  end

  # What identifier SDK (usually) expects
  def instance_identifier
    "instance_id"
  end

  private

  def project_tag_if_tag_filter
    errors.add(:project_tag, "Must be defined if filter level is tag") if filter_level == "tag" && !project_tag
  end
end
