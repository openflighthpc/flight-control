class InstanceLog < ApplicationRecord
  ON_STATUSES = {"azure" => "VM running",
                 "aws" => "running",
                 "example" => "running"}
  OFF_STATUSES = {"azure" => "VM deallocated",
                 "aws" => "stopped",
                 "example" => "stopped"}
  belongs_to :project
  validates :instance_type, :instance_name, :instance_id,
            :region, :status, :date, :last_checked,
            :last_status_change, presence: true
  validates :platform,
    presence: true,
    inclusion: {
      in: %w(aws azure example),
      message: "%{value} is not a valid platform"
    }

  before_save :set_if_status_changed

  def on?
    status == ON_STATUSES[platform]
  end

  # including at risk margin
  def hourly_compute_cost
    unless @hourly_compute_cost
      instance_details = InstanceTypeDetail.find_by(instance_type: instance_type, region: region) || InstanceTypeDetail.new
      @hourly_compute_cost = instance_details.price_per_hour
      @hourly_compute_cost = @hourly_compute_cost * CostLog.usd_gbp_conversion if instance_details.currency == "USD"
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

  def customer_facing_type
    if !@customer_facing
      @customer_facing = InstanceMapping.customer_facing_type(platform, instance_type)
    end
    @customer_facing
  end

  # JS doesn't work with instance types including '.'
  def front_end_instance_type
    instance_type.gsub(".", "_")
  end

  def has_mapping?
    !InstanceMapping.instance_mappings[platform][instance_type].nil?
  end

  def pending_status
    if !@pending 
      action_log = ActionLog.where(instance_id: instance_id).where(status: "pending").last
      if action_log
        if action_log.action == "on"
          @pending = ON_STATUSES[platform]
        else
          @pending = OFF_STATUSES[platform]
        end
      else
        @pending = status
      end
    end
    @pending
  end

  def pending_on?
    pending_status == ON_STATUSES[platform]
  end

  def resource_group
    return if platform == "aws" || platform == "example"
    
    instance_id.split("/")[4]
  end

  private

  def set_if_status_changed
    if status_changed?
      self.last_status_change = Time.current
    end
  end
end
