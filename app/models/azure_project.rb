require_relative 'project'
require_relative 'services/azure_instance_recorder'

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

  # In future this will be part of services, not project
  def refresh_auth_token
    @authorisor ||= AzureAuthoriser.new(self)
    @authorisor.refresh_auth_token
  end

  def record_instance_logs(rerun=false)
    AzureInstanceRecorder.new(self).record_logs(rerun)
  end

  private

  def resource_groups_if_group_filter
    errors.add(:resource_groups, "Must contain at least one value") if filter_level == "resource group" && resource_groups.empty?
  end
end
