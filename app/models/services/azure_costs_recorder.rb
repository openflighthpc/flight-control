require_relative 'azure_service'
require_relative '../azure_project'
require_relative '../cost_log'

class AzureCostsRecorder < AzureService

  def record_logs(date, rerun, verbose)
    all_costs = get_all_costs(date)
    
  end

  # The Azure API now treats 'modern' and 'legacy' subscriptions differently.
  # Despite being the same API, with the same version, these types expect different
  # params. The responses are also in different formats. This method caters to both.
  def get_all_costs(start_date, end_date=start_date)
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

  def data_out_costs(cost_entries, subscription_version)
    cost_entries.select do |cost|
      meter_name = subscription_version == "modern" ? cost["properties"]["meterName"] : cost["properties"]["meterDetails"]["meterName"]
      meter_name == "Data Transfer Out"
    end
  end

  def core_costs(cost_entries, subscription_version)
    cost_entries.select do |cost|
      meter_name = subscription_version == "modern" ? cost["properties"]["meterName"] : cost["properties"]["meterDetails"]["meterName"]
      cost["tags"] && cost["tags"]["type"] == "core" &&
      meter_name != "Data Transfer Out" && 
      !meter_name.include?("Disks")
    end
  end

  def core_storage_costs(cost_entries, subscription_version)
    cost_entries.select do |cost|
      meter_name = subscription_version == "modern" ? cost["properties"]["meterName"] : cost["properties"]["meterDetails"]["meterName"]
      cost["tags"] && cost["tags"]["type"] == "core" &&
      meter_name.include?("Disks")
    end
  end
end
