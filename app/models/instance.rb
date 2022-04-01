require_relative '../services/aws_instance_details_recorder'
require_relative '../services/azure_instance_details_recorder'
require_relative 'project'

class Instance
  @@instance_details = nil

  attr_reader :count, :details, :region, :instance_type, :group, :budget_switch_offs

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
    region_details = @@instance_details[region]
    @details = region_details[instance_type] if region_details
    @details ||= {}
    @future_counts = {}
    @budget_switch_offs = {}
  end

  def present_in_region?
    @details != {}
  end

  # JS doesn't work with instance types including '.'
  def front_end_instance_type
    instance_type.gsub(".", "_")
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
    @pending = true
  end

  def pending_change?
    @pending
  end

  def total_count
    @count[:on] + @count[:off]
  end

  def pending_on
    @count[:pending_on] || @count[:on]
  end

  # at start of day
  def pending_on_date(date, temp_counts=nil)
    count = pending_on
    if temp_counts
      original_future_counts = Project.deep_copy_hash(@future_counts)
      add_future_counts(temp_counts)
    end
    return count if @future_counts == {}

    dates = @future_counts.keys.sort
    previous_dates = dates.select { |d| d < date }
    previous_dates.each do |d|
      changes = @future_counts[d]
      # a change might be a budget switch off (exact count)
      # or a scheduled change (minimum count)
      changes.each do |time, details|
        if details[:min] == true
          count = [count, details[:count]].max
        else
          count = details[:count]
        end
      end
    end
    @future_counts = original_future_counts if temp_counts
    count
  end

  # at end of day (budget switch off time)
  def pending_on_date_end(date, temp_counts=nil)
    count = pending_on
    if temp_counts
      original_future_counts = Project.deep_copy_hash(@future_counts)
      add_future_counts(temp_counts)
    end
    return count if @future_counts == {}

    dates = @future_counts.keys.sort
    previous_dates = dates.select { |d| d <= date }
    previous_dates.each do |d|
      changes = @future_counts[d]
      # a change might be a budget switch off (exact count)
      # or a scheduled change (minimum count)
      changes.each do |time, details|
        if d != Date.today || time < Project::BUDGET_SWITCH_OFF_TIME
          if details[:min] == true
            count = [count, details[:count]].max
          else
            count = details[:count]
          end
        end
      end
    end
    @future_counts = original_future_counts if temp_counts
    count
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

  # Includes at risk margin
  def daily_compute_cost
    (daily_cost * CostLog.gbp_compute_conversion * CostLog.at_risk_conversion).ceil
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

  # assumes date is in the future
  def pending_daily_cost_with_future_counts(date)
    return pending_total_daily_compute_cost if @future_counts == {}

    count = pending_on_date(date)
    changes_on_date = @future_counts[date]
    return daily_compute_cost * count if !changes_on_date

    instances = {}
    total_count.times do |x|
      on = x < count
      instances[x] = {on: on, hours: 0, previous_time: date.to_time}
    end
    
    changes_on_date.each do |time, new_count_and_type|
      time = Time.parse("#{date} #{time}")
      new_count = new_count_and_type[:count]
      min_count = new_count_and_type[:min]
      total_count.times do |x|
        instance_on = x < new_count && !instances[x][:on]
        # only turn off if count is exact, not a minimum (i.e. budget switch offs)
        instance_off = x >= new_count && instances[x][:on] && !min_count
        change = instance_on || instance_off
        if change
          if instance_off
            extra_hours = ((time - instances[x][:previous_time])/ 3600).ceil
            instances[x][:hours] += extra_hours
          elsif instance_on
            instances[x][:previous_time] = time
          end
          instances[x][:on] = instance_on
        end
      end
    end

    total_cost = 0.0
    instances.each do |key, values|
      if instances[key][:on]
        previous_time_to_midnight = (((date + 1.day).to_time - instances[key][:previous_time]) / 3600).ceil
        instances[key][:hours] += previous_time_to_midnight
        instances[key][:hours] = [24, instances[key][:hours]].min
      end
      total_cost += (instances[key][:hours] * compute_cost_per_hour).ceil
    end
    total_cost.ceil
  end

  def add_future_counts(counts)
    counts.each do |date, times_and_counts|
      times_and_counts.each do |time, details|
        if @future_counts.has_key?(date)
          @future_counts[date][time] = details
        else
          @future_counts[date] = {time => details}
        end
      end
    end
    @future_counts
  end

  def add_budget_switch_offs(details)
    time = Project::BUDGET_SWITCH_OFF_TIME
    days = details.keys.sort # earlier switch offs must be processed first
    days.each do |days_in_future|
      to_switch_off = details[days_in_future]
      date = Date.today + days_in_future.days
      count = pending_on_date_end(date)
      if @future_counts[date]
        # has priority over any existing scheduled request at that time
        @future_counts[date][time] = {count: count - to_switch_off, min: false}
      else
        @future_counts[date] = {time => {count: count - to_switch_off, min: false}}
      end
      @budget_switch_offs[date] = to_switch_off
    end
  end

  def get_budget_switch_offs_as_schedules(switch_offs)
    original_future_counts = Project.deep_copy_hash(@future_counts)
    add_budget_switch_offs(switch_offs)
    just_switch_offs = {}
    @future_counts.each do |date, content|
      content.each do |time, count_and_type|
        # can't have more than one switch off schedule on the same day for the same Instance object
        just_switch_offs[date] = content if !count_and_type[:min]
      end
    end
    @future_counts = original_future_counts
    return just_switch_offs
  end

  def projected_costs_for_range(start_date, end_date)
    total = 0
    (start_date..end_date).to_a.each do |date|
      total += pending_daily_cost_with_future_counts(date)
    end
    total
  end

  def projected_costs_with_budget_switch_offs(switch_offs, start_date, end_date)
    original_counts = Project.deep_copy_hash(@future_counts)

    add_future_counts(switch_offs)
    total = projected_costs_for_range(start_date, end_date)
    @future_counts = original_counts
    total
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
      "Mem: #{mem}GiB, CPUs: #{cpus}, GPUs: #{gpus}"
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

  def priority
    @project.front_end_compute_groups.dig(@group, 'nodes', truncated_name, 'priority') ||
      @project.global_node_details.dig(truncated_name, 'priority') ||
      0
  end

  def group_priority
    @project.front_end_compute_groups[@group]["priority"]
  end

  def weighted_priority
    priority * group_priority
  end
end
