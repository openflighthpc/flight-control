require 'aws-sdk-cloudwatch'

class AwsMonitor
  def initialize(project)
    @project = project
  end

  def check_and_switch_off
    return if !@project.utilisation_threshold

    node_usage = get_nodes_usage
    under_threshold = {}
    node_usage.each do |region, instances|
      instances.each do |id, values|
        if values[:average] < @project.utilisation_threshold
          # Creating the action log should be done in project,
          # so this service class doesn't need to know about it
          ActionLog.create(project_id: @project.id,
                           instance_id: id,
                           reason: 'Utilisation below configured threshold',
                           action: "off")
          if under_threshold[region]
            under_threshold[region] << id
          else
            under_threshold[region] = [id]
          end
        end
      end
    end
    @project.update_instance_statuses({off: under_threshold})
  end

  # Results grouped by region, as this required for efficient switch offs
  # (if required)
  def get_nodes_usage
    # Probably should check directly with provider, as instance logs
    # could be out of date
    on = @project.latest_instance_logs.where(status: InstanceLog::ON_STATUSES["aws"])
    grouped = on.group_by { |instance| instance.region }
    results = {}
    grouped.each do |region, instances|
      results[region] = {}
      instances.each do |instance| 
        results[region][instance.instance_id] = get_node_usage(instance.instance_id, region)
      end
    end
    results
  end

  # Average and most recent value. For both we check the maximum values, for the past
  # 20 minutes.
  def get_node_usage(node, region)
    watcher = Aws::CloudWatch::Client.new(region: region)
    response = watcher.get_metric_statistics({
      namespace: "AWS/EC2",
      metric_name: "CPUUtilization",
      dimensions: [
        {
          name: "InstanceId",
          value: node
        }
      ],
      statistics: ["Maximum"],
      end_time: Time.now,
      start_time: (Time.now - 26*60), # As AWS only takes utilisation every 5 minutes,
      period: 60,                     # we take the last 26 minutes (~4/5 readings)
      unit: "Percent"                 # and use the latest 4 readings.
    })
    vals = response.datapoints.sort_by(&:timestamp).last(4).map(&:maximum)
    #logger.info("Maximum percentage CPU usage per 5 minutes for the last 20 minutes:")
    # logger.info(vals)
    last = vals.last
    last ||= 0

    # When there aren't enough average readings for last 20 mins, instead treat the node as 
    # if it were fully loaded. Should the note have less than 4 metrics this indicates that
    # it was likely turned on recently. This gives the node a grace period.
    #
    # NB: AWS has a minimum of 5 minutes per data point for the CPUUtilization metric,
    # which should explain the difference between the grace periods of the AWS and Azure
    # methods.
    if vals.length < 4
      return {average: 100, last: last}
    else
      return {average: (vals.inject { |sum, el| sum + el.to_i }.to_f / vals.size).round(2), last: last}
    end
  end
end
