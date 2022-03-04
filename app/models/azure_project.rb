require_relative 'project'
require_relative '../services/azure_service'
require_relative '../services/azure_instance_recorder'
require_relative '../services/azure_costs_recorder'
require_relative '../services/azure_authoriser'
require_relative '../services/azure_instance_details_recorder'
require_relative '../services/azure_instance_manager'

class AzureProject < Project
  alias_attribute :azure_client_id, :security_id
  alias_attribute :client_secret, :security_key
  validates :tenant_id, :subscription_id, presence: true
  validates :filter_level,
    presence: true,
    inclusion: {
      in: ["resource group", "subscription"],
      message: "%{value} is not a valid filter level. Must be resource group or subscription."
    }
  validate :resource_groups_if_group_filter

  default_scope { where(platform: "azure") }

  def describe_resource_groups
    resource_groups.join(", ")
  end

  def authoriser
    @authoriser ||= AzureAuthoriser.new(self)
  end

  def instance_recorder
    @instance_recorder ||= AzureInstanceRecorder.new(self)
  end

  def instance_manager
    @instance_manager ||= AzureInstanceManager.new(self)
  end

  def costs_recorder
    @costs_recorder ||= AzureCostsRecorder.new(self)
  end

  def instance_details_recorder
    @instance_details_recorder ||= AzureInstanceDetailsRecorder.new(self)
  end

  def monitor
    @monitor ||= AzureMonitor.new(self)
  end

  def record_cost_logs_for_range(start_date, end_date, rerun=false, text=false, verbose=false)
    puts "May take some time (5+ mins per month of data)" if text
    super(start_date, end_date, rerun, verbose, text)
  end

  def action_change_request(change)
    instances_to_change = change.instances_to_change_with_pending
    by_resource_group = {on: {}, off: {}}
    instances_to_change.each do |action, instances|
      instances.each do |instance|
        if by_resource_group[action].has_key?(instance.resource_group)
          by_resource_group[action][instance.resource_group] << instance.instance_name
        else
          by_resource_group[action][instance.resource_group] = [instance.instance_name]
        end
        action_log = ActionLog.new(project_id: self.id, user_id: change.user_id, 
                                   action: action, reason: "Change request",
                                   instance_id: instance.instance_id,
                                   change_request_id: change.actual_or_parent_id)
        action_log.save!
      end
    end
    update_instance_statuses(by_resource_group)
  end

  private

  def additional_validations
    authoriser.validate_credentials
  end

  def resource_groups_if_group_filter
    errors.add(:resource_groups, "Must contain at least one value") if filter_level == "resource group" && resource_groups.empty?
  end
end
