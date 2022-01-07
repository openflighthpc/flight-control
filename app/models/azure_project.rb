require_relative 'project'
require_relative 'services/azure_instance_recorder'
require_relative 'services/azure_costs_recorder'
require_relative 'services/azure_authoriser'

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

  def costs_recorder
    @costs_recorder ||= AzureCostsRecorder.new(self)
  end

  private

  def resource_groups_if_group_filter
    errors.add(:resource_groups, "Must contain at least one value") if filter_level == "resource group" && resource_groups.empty?
  end
end
