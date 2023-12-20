require_relative '../models/example_project'
require_relative '../models/cost_log'
require_relative 'example_api_error'
require_relative 'http_request'

class ExampleCostsRecorder

  def initialize(project)
    @project = project
  end

  def record_logs(start_date, end_date=start_date, rerun=false, verbose=false)
    Project::SCOPES.each { |scope| record_scope_logs(start_date: start_date,
                                                     end_date: end_date,
                                                     rerun: rerun,
                                                     verbose: verbose,
                                                     scope: scope
                                                    )
                         }
    @project.current_compute_groups.each do |group|
      record_scope_logs(start_date: start_date,
                        end_date: end_date,
                        rerun: rerun,
                        verbose: verbose,
                        scope: group,
                        compute_group: group)
    end
  end

  def record_scope_logs(start_date:, end_date: start_date, rerun:, verbose:, scope:, compute_group: nil)
    days = []
    cur = start_date
    while cur <= end_date
      days << cur
      cur = cur + 1 #Adding 1 to a Date object is 1 day
    end

    response = http_request(uri: 'http://0.0.0.0:4567/providers/example-provider/instances',
                            headers: {'Project-Credentials' => {'PROJECT_NAME': @project.name}.to_json},
                           )
    raise ExampleApiError, response.body unless response.code == "200"
    instances = JSON.parse(response.body)
    if compute_group
      instances = instances.select { |instance| instance['tags'].key?('compute_group') && instance['tags']['compute_group'] == compute_group }
    end
    instance_ids = instances.map { |instance| instance['instance_id'] }

    days.each do |day|
      existing_logs = @project.cost_logs.where(date: day).any?
      if !existing_logs || rerun
        response = http_request(uri: 'http://0.0.0.0:4567/providers/example-provider/instance-costs',
                                headers: {'Project-Credentials' => {'PROJECT_NAME': @project.name}.to_json},
                                query: {'instance_ids' => instance_ids,
                                        'start_time' => day.to_time.to_i,
                                        'end_time' => (day + 1).to_time.to_i
                                       }
                               )
        raise ExampleApiError, response.body unless response.code == "200"

        instance_data = JSON.parse(response.body)['costs']
        total = 0.0
        instance_data.each do |instance|
          total += instance['financial_data']['price'].to_f
        end
        log = @project.cost_logs.find_by(date: day, scope: scope)
        if rerun && log
          log.assign_attributes(cost: total)
          log.save!
        else
          log = CostLog.create(
            project_id: @project.id,
            cost: total,
            currency: instance_data.first['financial_data']['currency'],
            compute: compute_group.present?,
            date: day,
            scope: scope
          )
        end
        log
      end
    end
  end

  def validate_credentials
    response = http_request(uri: 'http://0.0.0.0:4567/providers/example-provider/validate-credentials',
                            request_type: "post",
                            headers: {'Project-Credentials' => {'PROJECT_NAME': @project.name}.to_json}
                           )
    response.code=="200"
  end
end
