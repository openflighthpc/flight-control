require_relative 'azure_service'
require_relative 'azure_authoriser'

class AzureInstanceRecorder < AzureService

  def initialize(project)
    super(project)
    @authorisor = AzureAuthoriser.new(project)
  end

  def record_logs(rerun=false)
    # can't record instance logs if resource group deleted
    if @project.archived
      return "Logs not recorded, project is archived"
    end

    outcome = ""
    today_logs = @project.instance_logs.where(date: Date.today)
    if today_logs.any?
      if rerun 
        outcome = "Overwriting existing logs. "
      else
        return "Logs already recorded for today. Run script again with 'rerun' to overwrite existing logs."
      end
    else
      outcome = "Writing new logs for today. "
    end
    
    today_logs.delete_all if rerun
    log_recorded = false
    if !today_logs.any?
      active_nodes = determine_current_compute_nodes
      any_nodes = active_nodes.any?
      active_nodes&.each do |node|
        # Azure API returns ids with inconsistent capitalisations so need to edit them here
        instance_id = node['id']
        instance_id.gsub!("resourcegroups", "resourceGroups")
        instance_id.gsub!("microsoft.compute/virtualmachines", "Microsoft.Compute/virtualMachines")
        instance_id_breakdown = instance_id.split("/")
        resource_group = instance_id_breakdown[4].downcase # sometimes Azure gives it uppercase, sometime lowercase
        instance_id_breakdown[4] = resource_group
        instance_id = instance_id_breakdown.join("/")
 
        name = node['id'].match(/virtualMachines\/(.*)\/providers/i)[1]
        region = node['location']
        cnode = today_compute_nodes.detect do |compute_node|
                  compute_node['name'] == name  && resource_group == compute_node['id'].split("/")[4].downcase
                end
        next if !cnode

        type = cnode['properties']['hardwareProfile']['vmSize']
        compute_group = cnode.key?('tags') ? cnode['tags']['compute_group'] : nil
        log = InstanceLog.create(
          instance_id: instance_id,
          project_id: @project.id,
          instance_type: type,
          instance_name: name,
          compute_group: compute_group,
          status: node['properties']['availabilityState'],
          platform: 'Azure',
          region: region,
          date: Date.today
        )
        log_recorded = true if log.valid? && log.persisted?
      end
    end
    outcome << (log_recorded ? "Logs recorded" : (any_nodes ? "Logs NOT recorded" : "No logs to record"))
    outcome
  end

  def determine_current_compute_nodes
    instances_with_statuses = api_query_compute_nodes
    instances_with_compute_groups = api_query_compute_nodes(false).select do |vm|
      vm.key?('tags') && vm['tags']['type'] == 'compute'
    end
    # puts "statusings"
    # puts instances_with_statuses
    # puts "groupings"
    # puts instances_with_compute_groups
    instances_with_compute_groups.each do |instance|
      status_result = instances_with_statuses.detect { |i| i["id"].downcase == instance["id"].downcase }
      status = status_result["properties"]["instanceView"]["statuses"].find { |status| status["code"] == "PowerState/deallocated" }["displayStatus"]
      instance["status"] = status
    end
  end

  def api_query_compute_nodes(status_only=true)
    uri = "https://management.azure.com/subscriptions/#{@project.subscription_id}/providers/Microsoft.Compute/virtualMachines"
    query = {
      'api-version': '2020-06-01',
      'statusOnly': status_only
    }
    attempt = 0
    error = AzureApiError.new("Timeout error querying compute nodes for project"\
                              "#{@project.name}. All #{MAX_API_ATTEMPTS} attempts timed out.")
    begin
      @authorisor.refresh_auth_token
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
