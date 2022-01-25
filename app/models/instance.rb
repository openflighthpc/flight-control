require_relative '../services/aws_instance_details_recorder'
require_relative '../services/azure_instance_details_recorder'
require_relative 'project'

class Instance
  @@instance_details = nil

  attr_reader :count, :details, :region, :instance_type, :group

  def self.instance_details
    if !@@instance_details
      set_instance_details
    end
    @@instance_details
  end

  def self.set_instance_details
    @@instance_details = {}
    set_azure_prices
    set_azure_instance_sizes
    set_aws_instance_details
  end

  # Azure prices are in GBP
  def self.set_azure_prices
    if File.exists?(AzureInstanceDetailsRecorder.prices_file)
      File.foreach(AzureInstanceDetailsRecorder.prices_file).with_index do |entry, index|
        puts entry
        if index > 0
          entry = JSON.parse(entry)

          instance_type = entry["armSkuName"] 
          region = entry["armRegionName"]
          if !@@instance_details.has_key?(region)
            @@instance_details[region] = {}
          end

          # Setting sizes shouldn't overwrite prices, and vice versa
          if @@instance_details[region][instance_type]
            @@instance_details[region][instance_type][:price] = entry["unitPrice"].to_f
          else
            @@instance_details[region][instance_type] = { price: entry["unitPrice"] }
          end
        end
      end
    else
      # @@azure_pricing_data_status = "none"
    end
  end

  def self.set_azure_instance_sizes
    if File.exists?(AzureInstanceDetailsRecorder.sizes_file)
      File.foreach(AzureInstanceDetailsRecorder.sizes_file).with_index do |entry, index|
        if index > 0
          entry = JSON.parse(entry)
          instance_type = entry['instance_type']
          region = entry['location']
          if !@@instance_details.has_key?(region)
            @@instance_details[region] = {}
          end

          # Setting sizes shouldn't overwrite prices, and vice versa
          if @@instance_details[region][instance_type]
            @@instance_details[region][instance_type][:cpu] = entry["cpu"]
            @@instance_details[region][instance_type][:gpu] = entry["gpu"]
            @@instance_details[region][instance_type][:mem] = entry["mem"]
          else
            @@instance_details[region][instance_type] = {
              cpu: entry["cpu"],
              gpu: entry["gpu"],
              mem: entry["mem"]
            }
          end
        end
      end
    else
      # @@azure_instance_data_status = "none"
    end
  end

  def self.set_aws_instance_details
    if File.exists?(AwsInstanceDetailsRecorder.details_file)
      File.foreach(AwsInstanceDetailsRecorder.details_file).with_index do |entry, index|
        if index > 0
          entry = JSON.parse(entry)
          instance_type = entry['instance_type']
          region = entry['location']
          if !@@instance_details.has_key?(region)
            @@instance_details[region] = {}
          end

          if !@@instance_details[region].has_key?(instance_type)
            @@instance_details[region][instance_type] = {
              price: entry['price_per_hour'].to_f,
              cpu: entry["cpu"],
              gpu: entry["gpu"],
              mem: entry["mem"]
            }
          end
        end
      end
    else
      # @@aws_data_status = "none"
    end
  end

  def initialize(instance_type, region, group, platform, project)
    @instance_type = instance_type
    @region = region
    @group = group
    @platform = platform
    @project = project
    @count = {on: 0, off: 0}
    self.class.set_instance_details if @@instance_details == nil
    region_details = @@instance_details[self.region]
    @details = region_details[instance_type] if region_details
    @details ||= {}
  end

  def present_in_region?
    @details != {}
  end

  def ==(other)
    self.instance_type == other.instance_type && self.region == other.region
  end

  def <=>(other)
    [self.weighted_priority, self.group_priority, self.mem] <=> [other.weighted_priority, other.group_priority, other.mem]
  end

  def increase_count(state, amount=1)
    @count[state] += amount
  end

  def set_pending_on(amount)
    @count[:pending_on] = amount
    @pending_change = true
  end

  def total_count
    @count[:on] + @count[:off]
  end

  def pending_on
    @count[:pending_on] || @count[:on]
  end

  def pending_change?
    @pending_change
  end

  def price_per_hour
    base_price = price || 0
    @platform == "aws" ? base_price * CostLog.usd_gbp_conversion : base_price
  end

  def price
    @details[:price] if @details[:price]
  end

  def daily_cost
    price_per_hour * 24
  end

  def daily_compute_cost
    (daily_cost * CostLog.gbp_compute_conversion).ceil
  end

  def total_daily_compute_cost
    daily_compute_cost * @count[:on]
  end

  def compute_cost_per_hour
    price_per_hour * CostLog.gbp_compute_conversion
  end

  # if no pending change, the same as actual
  def pending_total_daily_compute_cost
    daily_compute_cost * pending_on
  end

  def cpus
    @details[:cpu] || -1
  end

  def mem
    @details[:mem] || -1
  end

  def gpus
    @details[:gpu] || -1
  end

  def details_description
    if @details[:cpu]
      "Mem: #{mem}GiB, CPUs: #{cpus}, GPUs: #{gpus}, Weighted Priority: #{weighted_priority}"
    else
      "Unknown - please generate new instance details files"
    end
  end

  def details_and_cost_description
    details = details_description
    if @details[:cpu]
      details << ", Cost: #{daily_compute_cost} compute units/ day"
    end
  end

  def customer_facing_type
    if !@customer_facing
      @customer_facing = InstanceMapping.customer_facing_type(@platform, instance_type)
    end
    @customer_facing
  end

  def truncated_name
    if !@truncated_name
      @truncated_name = customer_facing_type.downcase.gsub(' ', '_').gsub(/[()]/, '')
    end
    @truncated_name
  end

  def node_limit
    @project.front_end_compute_groups.dig(@group, 'nodes', truncated_name, 'limit') || 0
  end
end
