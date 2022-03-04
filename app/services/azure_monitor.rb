require 'httparty'
require_relative 'azure_service'

class AzureMonitor < AzureService
  include MonitorLogging

  def check_and_switch_off(slack=false)
    return if !@project.utilisation_threshold

    @loggers = {}
    node_usage = get_nodes_usage
    under_threshold = {}
    node_usage.each do |resource_group, instances|
      logger = @loggers[resource_group]
      instances.each do |id, values|
        if values[:average] < @project.utilisation_threshold
          logger.info("Turning off #{values[:name]}")
          # Creating the action log should be done in project,
          # so this service class doesn't need to know about it
          ActionLog.create(project_id: @project.id,
                           instance_id: id,
                           reason: 'Utilisation below configured threshold',
                           action: "off")
          if slack
            msg = "Shutting down #{values[:name]} (20 min avg of max load is #{values[:average]}; this is " \
                  "lower than threshold of #{@project.utilisation_threshold})"
            @project.send_slack_message(msg)
          end
          if under_threshold[resource_group]
            under_threshold[resource_group] << values[:name]
          else
            under_threshold[resource_group] = [values[:name]]
          end
        end
      end
    end
    @project.update_instance_statuses({off: under_threshold})
  end

  # Results grouped by region, as this required for efficient switch offs
  # (if required)
  def get_nodes_usage
    # Ensure we have up to date logs
    if @project.latest_instance_logs.maximum(:updated_at) < (Time.now - 1.minute)
      @project.record_instance_logs(true)
    end
    on = @project.latest_instance_logs.where(status: InstanceLog::ON_STATUSES["azure"])
    grouped = on.group_by { |instance| instance.resource_group }
    @loggers ||= {}
    results = {}
    @project.resource_groups.each do |resource_group|
      results[resource_group] = {}
      logger = setup_logger(resource_group)
      @loggers[resource_group] = logger
      instances = grouped[resource_group]
      if instances
        logger.info("Checking utilisation of running instances for group #{resource_group}")
        instances.each do |instance| 
          results[resource_group][instance.instance_id] = get_node_usage(instance.instance_id, resource_group, logger)
          results[resource_group][instance.instance_id][:name] = instance.instance_name
        end
      else
        logger.info("No running nodes for group #{resource_group}")
      end
    end
    results
  end

  def get_node_usage(node_id, resource_group, logger=nil)
    logger ||= setup_logger(resource_group)
    logger.info("Getting utilisation data for #{node_id}")
    @project.authoriser.refresh_auth_token
    uri = "https://management.azure.com/#{node_id}/providers/microsoft.insights/metrics"

    query = {
      "api-version": "2019-07-01",
      "metricnames": "Percentage CPU",
      "aggregation": "Maximum",
      "timespan": "PT26M",
    }

    response = HTTParty.get(
      uri,
      query: query,
      headers: { 'Authorization': "Bearer #{@project.bearer_token}" },
      timeout: DEFAULT_TIMEOUT
    )

    if response.success?
      last = nil
      logger.info("Maximum percentage CPU usage per 1 minute for the last 20 minutes:")
      usage = response['value'].first['timeseries'].first['data']
      vals = usage.map do |i|
        logger.info("#{i['timeStamp']}: #{i['maximum']}")
        last = i["maximum"]
        i['maximum']
      end.compact
      vals = vals.last(20)

      # When there aren't enough average readings for last 20 mins, instead treat the node as 
      # if it were fully loaded. Should the note have less than 20 metrics this indicates that
      # it was likely turned on recently. This gives the node a grace period.
      last ||= 0
      if vals.length < 20
        return {average: 100, last: last}
      else
        return {average: (vals.inject { |sum, el| sum + el.to_i }.to_f / vals.size).round(2), last: last }
      end
    else
      logger.error("Unable to get utlisation data for #{node_id}")
      raise AzureApiError.new("Instance usage request timed out for project #{project}")
    end
  end
end
