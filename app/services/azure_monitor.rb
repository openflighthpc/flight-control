require 'httparty'
require_relative 'azure_service'

class AzureMonitor < AzureService

  def get_nodes_usage
    # Ensure we have up to date logs
    if @project.latest_instance_logs.maximum(:updated_at) < (Time.now - 1.minute)
      @project.record_instance_logs(true)
    end
    on = @project.latest_instance_logs.where(status: InstanceLog::ON_STATUSES["azure"])
    results = {}
    on.each do |instance| 
      results[instance.instance_id] = get_node_usage(instance.instance_id)
      # Need the name for slack
      results[instance.instance_id][:name] = instance.instance_name
    end
    results
  end

  def get_node_usage(node_id)
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
      #logger.info("Maximum percentage CPU usage per 1 minutes for the last 20 minutes:")
      usage = response['value'].first['timeseries'].first['data']
      vals = usage.map do |i|
        #logger.info("#{i['timeStamp']}: #{i['maximum']}")
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
      raise AzureApiError.new("Instance usage request timed out for project #{project}")
    end
  end
end
