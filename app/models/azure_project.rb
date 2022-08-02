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

  # How instances must be grouped for SDK queries, e.g. switch ons/offs
  def instance_grouping
    "resource_group"
  end

  # What API (usually) expects
  def instance_identifier
    "instance_name"
  end

  private

  def additional_validations
    authoriser.validate_credentials
  end

  def resource_groups_if_group_filter
    errors.add(:resource_groups, "Must contain at least one value") if filter_level == "resource group" && resource_groups.empty?
  end
end
