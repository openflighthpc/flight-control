require_relative 'azure_service'
require_relative '../models/cost_log'

class AzureCostsRecorder < AzureService

  # Azure doesn't allow filtering in the query, so we make
  # once request for all costs and filter them within our application.
  def record_logs(date, rerun, verbose)
    existing_logs = @project.cost_logs.where(date: date).any?
    if !existing_logs || rerun
      all_costs = get_all_costs(date, date, verbose)
      subscription_version = all_costs[0]["kind"] if all_costs.any?
      Project::SCOPES.each { |scope| record_costs(all_costs, date, scope, subscription_version) }
      all_compute_costs = compute_costs(all_costs, subscription_version)
      @project.compute_groups.each do |group|
        group_costs = all_compute_group_costs(all_compute_costs, subscription_version, group)
        record_costs(group_costs, date, group, subscription_version, group)
        record_costs(group_costs, date, "#{group}_storage", subscription_version, group)  
      end
    end
  end

  # The Azure API now treats 'modern' and 'legacy' subscriptions differently.
  # Despite being the same API, with the same version, these types return data
  # with different key structures. This method caters to both.
  def record_costs(all_costs, date, scope, subscription_version, compute_group=nil)
    puts "#{Time.now} recording #{scope}"
    if compute_group
      if scope.include?("storage")
        filtered_costs = compute_group_storage_costs(all_costs, subscription_version)
      else
        filtered_costs = compute_group_costs(all_costs, subscription_version)
      end
    else
      filtered_costs = self.send("#{scope}_costs", all_costs, subscription_version)
    end
    cost_key = get_cost_key(subscription_version)
    total = filtered_costs.reduce(0.0) { |sum, cost| sum + cost['properties'][cost_key] }
    currency_key = get_currency_key(subscription_version)
    currency = all_costs.first["properties"][currency_key] if all_costs.any?
    currency ||= "GBP"
    
    log = @project.cost_logs.find_by(date: date, scope: scope)
    if log
      log.assign_attributes(cost: total, currency: currency)
      log.save!
    else
      log = CostLog.create(
        project_id: @project.id,
        cost: total,
        currency: currency,
        date: date,
        scope: scope,
      )
    end
    log
  end

  # The Azure API now treats 'modern' and 'legacy' subscriptions differently.
  # Despite being the same API, with the same version, these types expect different
  # params. This method caters to both.
  def get_all_costs(start_date, end_date=start_date, verbose)
    # This is for 'legacy', which the API can filter by resource group
    resource_groups_conditional = ""
    if @project.filter_level == "resource group"
      @project.resource_groups.each_with_index do |group, index|
        if index == 0
          resource_groups_conditional << "and properties/resourceGroup eq '#{group}'"
        else
          resource_groups_conditional << " or properties/resourceGroup eq '#{group}'"
        end
      end
    end
    filter = "properties/usageStart ge '#{start_date.to_s}' and properties/usageEnd le '#{end_date.to_s}'"
    filter << " #{resource_groups_conditional}" if @project.filter_level == "resource group"
    uri = "https://management.azure.com/subscriptions/#{@project.subscription_id}/providers/Microsoft.Consumption/usageDetails?$expand=meterDetails"
    query = {
      'api-version': '2019-10-01',
      '$filter': filter,
      'startDate': start_date,
      'endDate': end_date
    }
    attempt = 0
    error = AzureApiError.new("Timeout error querying daily cost Azure API for project"\
                              " #{@project.name}. All #{MAX_API_ATTEMPTS} attempts timed out.")
    begin
      attempt += 1
      @project.authoriser.refresh_auth_token
      response = HTTParty.get(
        uri,
        query: query,
        headers: { 'Authorization': "Bearer #{@project.bearer_token}" },
        timeout: DEFAULT_TIMEOUT
      )
      if response.success?
        details = response['value']
        subscription_version = details[0]["kind"] if details.length > 0
        # Sometimes Azure will duplicate cost items, or have cost items with the same name/id but different
        # details. We will remove the full duplicates and keep those with the same name/id but different details.
        # We assume there is no more than 1 duplicate for each
        if details.length > 1
          cost_key = subscription_version == "modern" ? "costInBillingCurrency" : "cost"
          details.sort_by! { |cost| [cost["name"], cost['properties'][cost_key]] }
          previous = nil
          filtered_details = details.reject.with_index do |cost, index|
            result = false
            if index > 0
              result = cost == previous
            end
            previous = cost
            result
          end
        end
        details = filtered_details ? filtered_details : details
        # if modern subscription and have resource groups, we need to filter them here
        if details.length > 0 && subscription_version == "modern" && @project.resource_groups
          details = details.select { |cost| @project.resource_groups.include?(cost['properties']["resourceGroup"].downcase) }
        end
        details
      elsif response.code == 504
        raise Net::ReadTimeout
      else
        raise AzureApiError.new("Error querying daily cost Azure API for project #{name}.\nError code #{response.code}.\n#{response if @verbose}")
      end
    rescue Net::ReadTimeout
      msg = "Attempt #{attempt}: Request timed out.\n"
      if response
        msg << "Error code #{response.code}.\n#{response if @verbose}\n"
      end
      error.error_messages.append(msg)
      if attempt < MAX_API_ATTEMPTS
        retry
      else
        raise error
      end
    end 
  end

  private

  def total_costs(cost_entries, subscription_version)
    cost_entries
  end

  def data_out_costs(cost_entries, subscription_version)
    cost_entries.select do |cost|
      meter_name = get_meter_name(cost, subscription_version)
      meter_name == "Data Transfer Out"
    end
  end

  def core_costs(cost_entries, subscription_version)
    cost_entries.select do |cost|
      meter_name = get_meter_name(cost, subscription_version)
      cost["tags"] && cost["tags"]["type"] == "core" &&
      meter_name != "Data Transfer Out" && 
      !storage_cost?(meter_name)
    end
  end

  def storage_costs(cost_entries, subscription_version)
    cost_entries.select do |cost|
      meter_name = get_meter_name(cost, subscription_version)
      storage_cost?(meter_name)
    end
  end

  def core_storage_costs(cost_entries, subscription_version)
    cost_entries.select do |cost|
      meter_name = get_meter_name(cost, subscription_version)
      cost["tags"] && cost["tags"]["type"] == "core" &&
      storage_cost?(meter_name)
    end
  end

  def compute_costs(cost_entries, subscription_version)
    cost_entries.select do |cost|
      cost["tags"] && cost["tags"]["type"] == "compute"
    end
  end

  def all_compute_group_costs(compute_cost_entries, subscription_version, group)
    compute_cost_entries.select do |cost|
      cost["tags"] && cost["tags"]["compute_group"] == group
    end
  end

  def compute_group_storage_costs(compute_group_cost_entries, subscription_version)
    compute_group_cost_entries.select do |cost|
      storage_cost?(get_meter_name(cost, subscription_version))
    end
  end

  # Just instance costs
  def compute_group_costs(compute_group_cost_entries, subscription_version)
    compute_group_cost_entries.select do |cost|
      get_meter_category(cost, subscription_version) == "Virtual Machines"
    end
  end

  def get_meter_name(cost, subscription_version)
    subscription_version == "modern" ? cost["properties"]["meterName"] : cost["properties"]["meterDetails"]["meterName"]
  end

  def get_meter_category(cost, subscription_version)
    subscription_version == "modern" ? cost["properties"]["meterCategory"] : cost["properties"]["meterDetails"]["meterCategory"]
  end

  def get_cost_key(subscription_version)
    subscription_version == "modern" ? "costInBillingCurrency" : "cost"
  end

  def get_currency_key(subscription_version)
    subscription_version == "modern" ? "billingCurrencyCode" : "billingCurrency"
  end

  def storage_cost?(meter_name)
    meter_name.include?("Disks")
  end
end
