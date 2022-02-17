class InstanceLog < ApplicationRecord
  ON_STATUSES = {"azure" => "VM running",
                 "aws" => "running"}
  OFF_STATUSES = {"azure" => "VM deallocated",
                 "aws" => "stopped"}
  belongs_to :project
  validates :instance_type, :instance_name, :instance_id,
            :region, :status, :date, presence: true
  validates :platform,
    presence: true,
    inclusion: {
      in: %w(aws azure),
      message: "%{value} is not a valid platform"
    }

  def on?
    status == ON_STATUSES[platform]
  end

  # including at risk margin
  def hourly_compute_cost
    if !@hourly_compute_cost
      price = Instance.instance_details.dig(region, instance_type, :price)
      @hourly_compute_cost = price || 0
      @hourly_compute_cost = @hourly_compute_cost * CostLog.usd_gbp_conversion if platform == "aws"
      @hourly_compute_cost = @hourly_compute_cost * CostLog.gbp_compute_conversion
      @hourly_compute_cost = @hourly_compute_cost * CostLog.at_risk_conversion
    end
    @hourly_compute_cost
  end

  def daily_compute_cost
    (hourly_compute_cost * 24).ceil
  end

  def actual_cost
    on? ? daily_compute_cost : 0.0
  end

  def has_mapping?
    !InstanceMapping.instance_mappings[platform][instance_type].nil?
  end

  def pending_on?
    if !@pending_on
      action_log = ActionLog.where(instance_id: instance_id).where(status: "pending").last
      if action_log
        @pending_on = action_log.action == "on"
      else
        @pending_on = on?
      end
    end
    @pending_on
  end

  def resource_group
    return if platform == "aws"
    
    instance_id.split("/")[4]
  end
end
