require_relative 'project'
require_relative '../services/aws_instance_recorder'
require_relative '../services/aws_costs_recorder'
require_relative '../services/aws_instance_details_recorder'
require_relative '../services/aws_instance_manager'

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

  # Instance type prices and sizes
  def instance_details_recorder
    @instance_details_recorder ||= AwsInstanceDetailsRecorder.new(self)
  end

  def action_change_request(change)
    instance_ids = {on: {}, off: {}}
    instances_to_change.each do |action, instances|
      instances.each do |instance|
        if instance_ids[action].has_key?(instance.region)
          instance_ids[action][instance.region] << instance.instance_id
        else
          instance_ids[action][instance.region] = [instance.instance_id]
        end
        action_log = ActionLog.new(project_id: self.id, action: action, reason: "Change request",
                                   instance_id: instance.instance_id,
                                   change_request_id: change.actual_or_parent_id)
        action_log.save!
      end
    end
    update_instance_statuses(by_resource_group)
  end

  private

  def project_tag_if_tag_filter
    errors.add(:project_tag, "Must be defined if filter level is tag") if filter_level == "tag" && !project_tag
  end

  def regions_not_empty
    errors.add(:regions, "Must contain at least one value") if regions.empty?
  end
end
