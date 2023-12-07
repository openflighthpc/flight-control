require_relative '../models/example_project'
require_relative '../models/instance_log'
require_relative 'example_errors'
require_relative 'request_generator'

class ExampleInstanceRecorder

  def initialize(project)
    @project = project
  end

  def record_logs(rerun=false, verbose=false)
    today_logs = @project.instance_logs.where(date: Date.current)
    any_nodes = false
    log_recorded = false
    if !today_logs.any? || rerun
      log_ids = []
      response = http_request(uri: 'http://0.0.0.0:4567/providers/example-provider/instances',
                              headers: {'Project-Credentials' => {'PROJECT_NAME': @project.name}.to_json}
                             )
      raise ExampleApiError, response.body unless response.code == "200"

      instances = JSON.parse(response.body)
      any_nodes = true if instances.any?

      instances.each do |instance|
        log = today_logs.find_by(instance_id: instance['instance_id'])
        if !log
          log = InstanceLog.create(
            instance_id: instance['instance_id'],
            project_id: @project.id,
            instance_name: instance['instance_id'],
            instance_type: instance['model'],
            compute_group: instance['tags']['compute_group'] || nil,
            status: instance['state'],
            platform: 'example',
            region: instance['region'],
            date: Date.current,
            last_checked: Time.now,
            last_status_change: Time.now
          )
        else
          log.status = instance['status']
          log.compute_group = compute_group # rare, but could have changed
          log.last_checked = Time.now
          log.save
        end
        log_recorded = true if log.valid? && log.persisted?
        log_ids << log.id
      end
      # If any instances have been deleted, ensure logs recorded as inactive.
      # Can't delete them as that may interfere with forecasts, action logs, etc.
      if log_ids.length != today_logs.count
        obsolete_logs = today_logs.where("id NOT IN (?)", log_ids.compact)
        obsolete_logs.update_all(status: "stopped")
      end
    end
    log_recorded ? "Logs recorded" : (any_nodes ? "Logs NOT recorded" : "No logs to record")
  end

  def validate_credentials
    response = http_request(uri: 'http://0.0.0.0:4567/providers/example-provider/validate-credentials',
                            request_type: "post",
                            headers: {'Project-Credentials' => {'PROJECT_NAME': @project.name}.to_json}
                           )
    response.code=="200"
  end
end
