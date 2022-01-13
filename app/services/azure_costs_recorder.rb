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
      currency = get_currency(all_costs[0], subscription_version)
      scope_costs = determine_scope_costs(all_costs, subscription_version)
      create_logs(scope_costs, date, currency)
    end
    true
  end

  def create_logs(scope_costs, date, currency)
    scope_costs.each do |scope, details|
      total = details[:total]
      compute = details[:compute]
      log = @project.cost_logs.find_by(date: date, scope: scope)
      if log
        log.assign_attributes(cost: total, currency: currency)
        log.save!
      else
        log = CostLog.create(
          project_id: @project.id,
          cost: total,
          currency: currency,
          compute: compute,
          date: date,
          scope: scope,
        )
      end
    end
  end

  # The Azure API now treats 'modern' and 'legacy' subscriptions differently.
  # Despite being the same API, with the same version, these types return data
  # with different key structures. This method caters to both.
  def determine_scope_costs(all_costs, subscription_version)
    costs = {}
    Project::SCOPES.each { |scope| costs[scope] = {total: 0.0, compute: false}}
    @project.compute_groups.each do |group|
      costs[group] = {total: 0.0, compute: true}
      costs["#{group}_storage"] = {total: 0.0, compute: true}
    end
    cost_key = get_cost_key(subscription_version)

    all_costs.each do |cost|
      value = cost['properties'][cost_key]
      meter_name = get_meter_name(cost, subscription_version)
      costs["total"][:total] += value
      # Other than total, all other datasets are mutually exclusive,
      # so we can iterate once through all costs to get values.
      if data_out_cost?(meter_name)
        costs["data_out"][:total] += value
      elsif core_cost?(cost)
        if storage_cost?(meter_name)
          costs["core_storage"][:total] += value
        else
          costs["core"][:total] += value
        end
      elsif compute_cost?(cost)
        compute_group = cost["tags"]["compute_group"] if cost["tags"]
        if compute_group # in an if clause in case not tagged correctly
          if storage_cost?(meter_name)
            costs["#{compute_group}_storage"][:total] += value
          elsif virtual_machine_cost?(cost, subscription_version)
            costs[compute_group][:total] += value
          end
        end
      end
    end
    costs
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

  def validate_credentials
    valid = true
    begin
      get_all_costs(Project::DEFAULT_COSTS_DATE, Project::DEFAULT_COSTS_DATE, true)
    rescue => error
      puts "Unable to obtain costs data: #{error}"
      valid = false
    end
    valid
  end

  private

  # These methods to handle differences in output depending upon subscription version
  def get_meter_name(cost, subscription_version)
    subscription_version == "modern" ? cost["properties"]["meterName"] : cost["properties"]["meterDetails"]["meterName"]
  end

  def get_meter_category(cost, subscription_version)
    subscription_version == "modern" ? cost["properties"]["meterCategory"] : cost["properties"]["meterDetails"]["meterCategory"]
  end

  def get_cost_key(subscription_version)
    subscription_version == "modern" ? "costInBillingCurrency" : "cost"
  end

  def get_currency(cost, subscription_version)
    currency_key = subscription_version == "modern" ? "billingCurrencyCode" : "billingCurrency"
    currency = cost["properties"][currency_key] if cost
    currency ||= "GBP"
  end

  def data_out_cost?(meter_name)
    meter_name == "Data Transfer Out"
  end

  def storage_cost?(meter_name)
    meter_name.include?("Disks")
  end

  def core_cost?(cost)
    cost["tags"] && cost["tags"]["type"] == "core"
  end

  def compute_cost?(cost)
    cost["tags"] && cost["tags"]["type"] == "compute"
  end

  def virtual_machine_cost?(cost, subscription_version)
    get_meter_category(cost, subscription_version) == "Virtual Machines"
  end
end
