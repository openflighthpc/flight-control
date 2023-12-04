require_relative '../models/example_project'
require_relative '../models/cost_log'
require_relative 'example_errors'

class ExampleCostsRecorder

  def initialize(project)
    @project = project
  end

  def record_logs(start_date, end_date=start_date, rerun=false, verbose=false)
    days = []
    cur = start_date
    while cur <= end_date
      days << cur
      cur = cur + 1 #Adding 1 to a Date object is 1 day
    end

    response = http_request(uri: 'http://0.0.0.0:4567/providers/example-provider/instances',
                            headers: {'Project-Credentials' => {'PROJECT_NAME': @project.project_name}.inspect,
                           )
    raise ExampleApiError "Couldn't retrieve instance data" unless response.code == 200
    instance_ids = JSON.parse(response.body).map { |instance| instance['instance_id'] }

    existing_logs = @project.cost_logs.where(date: date).any?
    if !existing_logs || rerun
      days.each do |day|
        response = http_request(uri: 'http://0.0.0.0:4567/providers/example-provider/instance-costs',
                          headers: {'Project-Credentials' => {'PROJECT_NAME': @project.project_name}.inspect,
                          query: {'instance_ids' => instance_ids,
                                  'start_time' => day.to_time.to_i,
                                  'end_time' => (day + 1).to_time.to_i}
                         )
        raise ExampleApiError "Couldn't retrieve cost data" unless response.code == 200

        instance_data = JSON.parse(response.body)['usages']
        instance_data.each do |instance|
          log = @project.cost_logs.find_by(date: day, scope: scope)
          if rerun && log
            log.assign_attributes(cost: instance['price'].to_f)
            log.save!
          else
            log = CostLog.create(
              project_id: @project.id,
              cost: instance['price'].to_f,
              currency: instance['currency'],
              compute: nil,
              date: day,
              scope: scope
            )
          end
          log
        end
      end
    end
  end

  def validate_credentials
    response = http_request(uri: 'http://0.0.0.0:4567/providers/example-provider/validate-credentials',
                            headers: {'Project-Credentials' => {'PROJECT_NAME': @project.project_name}.inspect
                           )
    response.code==200
  end
end
