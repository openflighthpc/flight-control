require 'aws-sdk-cloudwatch'
require_relative 'monitor_logging'

class AwsMonitor
  include MonitorLogging

  def initialize(project)
    @project = project
  end

  def check_and_switch_off(slack=false)
    return if !@project.utilisation_threshold || !@project.monitor_currently_active?

    @loggers = {}
    node_usage = get_nodes_usage
    under_threshold = {}
    node_usage.each do |region, instances|
      logger = @loggers[region]
      instances.each do |id, values|
        if values[:average] < @project.utilisation_threshold
          logger.info("Turning off #{values[:name]}")
          ActionLog.create(project_id: @project.id,
                           instance_id: id,
                           reason: 'Utilisation below configured threshold',
                           action: "off",
                           automated: true)
          if slack
            msg = "Shutting down #{values[:name]} (20 min avg of max load is #{values[:average].round(2)}; this is " \
                  "lower than threshold of #{@project.utilisation_threshold})"
            @project.send_slack_message(msg)
          end
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
    # Ensure we have up to date logs
    if @project.latest_instance_logs.maximum(:updated_at) < (Time.current - 1.minute)
      @project.record_instance_logs(true)
    end
    on = @project.latest_instance_logs.where(status: InstanceLog::ON_STATUSES["aws"])
    grouped = on.group_by { |instance| instance.region }
    @loggers ||= {}
    results = {}
    @project.regions.each do |region|
      results[region] = {}
      logger = setup_logger(region)
      @loggers[region] = logger
      instances = grouped[region]
      if instances
        logger.info("Checking utilisation of running instances for region #{region}")
        instances.each do |instance| 
          results[region][instance.instance_id] = get_node_usage(instance.instance_id, region, logger)
          # Need the name for slack
          results[region][instance.instance_id][:name] = instance.instance_name
        end
      else
        logger.info("No running nodes for region #{region}")
      end
    end
    results
  end

  # Average and most recent value. For both we check the maximum values, for the past
  # 20 minutes.
  def get_node_usage(node_id, region, logger=nil)
    logger ||= setup_logger(region)
    logger.info("Getting utilisation data for #{node_id}")
    watcher = Aws::CloudWatch::Client.new(region: region)
    response = watcher.get_metric_statistics({
      namespace: "AWS/EC2",
      metric_name: "CPUUtilization",
      dimensions: [
        {
          name: "InstanceId",
          value: node_id
        }
      ],
      statistics: ["Maximum"],
      end_time: Time.current,
      start_time: (Time.current - 26*60), # As AWS only takes utilisation every 5 minutes,
      period: 60,                     # we take the last 26 minutes (~4/5 readings)
      unit: "Percent"                 # and use the latest 4 readings.
    })
    vals = response.datapoints.sort_by(&:timestamp).last(4).map(&:maximum)
    logger.info("Maximum percentage CPU usage per 5 minutes for the last 20 minutes:")
    logger.info(vals)
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
      return {average: (vals.inject(0.0) { |sum, el| sum + el } / vals.size), last: last}
    end
  end
end
