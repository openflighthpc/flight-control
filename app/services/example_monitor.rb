require_relative 'monitor_logging'
require_relative 'example_errors'

class ExampleMonitor
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
    on = @project.latest_instance_logs.where(status: InstanceLog::ON_STATUSES["example"])
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
  # Room here to reduce number of API calls
  def get_node_usage(node_id, region, logger=nil)
    logger ||= setup_logger(region)
    logger.info("Getting utilisation data for #{node_id}")
    now = Time.now.to_i

    response = http_request(uri: 'http://0.0.0.0:4567/providers/example-provider/instance_usages',
                            headers: {'Project-Credentials' => {'PROJECT_NAME': @project.project_name}.inspect},
                            query: {'instance_ids': node_id,
                                    'scope': scope,
                                    'start_time': now,
                                    'end_date': now + 1200
                                   }
                           )

    raise ExampleApiError "Couldn't retrieve usage data" unless response.code == 200

    body = JSON.parse(response.body)
    logger.info("Response received from Control API:")
    logger.info(body)
    usages = body['usages'].first
    return {average: usages['average'], last: usages['last']}
  end
end
