require_relative 'azure_service'
require_relative '../models/instance_log'

class AzureInstanceRecorder < AzureService

  def record_logs(rerun=false, verbose=false)
    today_logs = @project.instance_logs.where(date: Date.today)
    any_nodes = false
    log_recorded = false
    if !today_logs.any? || rerun
      active_nodes = determine_current_compute_nodes(verbose)
      any_nodes = active_nodes.any?
      log_ids = []
      active_nodes&.each do |node|
        # Azure API returns ids with inconsistent capitalisations so need to edit them here
        instance_id = node['id']
        instance_id.gsub!("resourcegroups", "resourceGroups")
        instance_id.gsub!("microsoft.compute/virtualmachines", "Microsoft.Compute/virtualMachines")
        instance_id_breakdown = instance_id.split("/")
        resource_group = instance_id_breakdown[4].downcase # sometimes Azure gives it uppercase, sometime lowercase
        instance_id_breakdown[4] = resource_group
        instance_id = instance_id_breakdown.join("/")
 
        name = node['name']
        region = node['location']
        type = node['properties']['hardwareProfile']['vmSize']
        compute_group = node['tags']['compute_group']
        status = node['status']
        log = today_logs.find_by(instance_id: instance_id)
        if !log
          log = InstanceLog.create(
            instance_id: instance_id,
            project_id: @project.id,
            instance_type: type,
            instance_name: name,
            compute_group: compute_group,
            status: status,
            platform: 'azure',
            region: region,
            date: Date.today
          )
        else
          log.status = status
          log.compute_group = compute_group # rare, but could have changed
          log.save
        end
        log_recorded = true if log.valid? && log.persisted?
        log_ids << log.id
      end
      # If any instances have been deleted, ensure logs recorded as inactive.
      # Can't delete them as that may interfere with forecasts, action logs, etc.
      if log_ids.length != today_logs.count
        obsolete_logs = today_logs.where("id NOT IN (?)", log_ids.compact)
        obsolete_logs.update_all(status: "VM Deallocated")
      end
    end
    log_recorded ? "Logs recorded" : (any_nodes ? "Logs NOT recorded" : "No logs to record")
  end

  # Azure APIs won't tell us instances' tags and statuses in the same query,
  # so we must make two and compare & combine the results
  def determine_current_compute_nodes(verbose)
    instances_with_statuses = api_query_compute_nodes(true, verbose)
    instances_with_compute_groups = api_query_compute_nodes(false, verbose).select do |vm|
      vm.key?('tags') && vm['tags']['type'] == 'compute'
    end
    instances_with_compute_groups.each do |instance|
      status_result = instances_with_statuses.detect { |i| i["id"].downcase == instance["id"].downcase }
      status = status_result["properties"]["instanceView"]["statuses"].find { |status| status["code"].starts_with?("PowerState") }["displayStatus"]
      instance["status"] = status
    end
  end

  def api_query_compute_nodes(status_only, verbose=false)
    uri = "https://management.azure.com/subscriptions/#{@project.subscription_id}/providers/Microsoft.Compute/virtualMachines"
    query = {
      'api-version': '2021-07-01',
      'statusOnly': status_only
    }
    attempt = 0
    error = AzureApiError.new("Timeout error querying compute nodes for project"\
                              "#{@project.name}. All #{MAX_API_ATTEMPTS} attempts timed out.")
    begin
      @project.authoriser.refresh_auth_token
      attempt += 1
      response = HTTParty.get(
        uri,
        query: query,
        headers: { 'Authorization': "Bearer #{@project.bearer_token}" },
        timeout: DEFAULT_TIMEOUT
      )

      if response.success?
        vms = response['value']
        vms.select { |vm| @project.filter_level == "subscription" ||
        (@project.filter_level == "resource group" && @project.resource_groups.include?(vm['id'].split('/')[4].downcase)) }
      elsif response.code == 504
        raise Net::ReadTimeout
      else
        raise AzureApiError.new("Error querying compute nodes for project #{name}."\
                                "\nError code #{response.code}.\n#{response if @verbose}")
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
end
