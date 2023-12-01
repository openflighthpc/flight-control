require_relative '../models/example_project'
require_relative '../models/cost_log'

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
    
    instance_ids = JSON.parse(http_request(uri: 'http://0.0.0.0:4567/providers/example-provider/instances',
                                           headers: {'Project-Credentials' => {'PROJECT_NAME': 'dummy-project'}.inspect,
                                          )
                             ).map { |instance| instance['instance_id'] }

    existing_logs = @project.cost_logs.where(date: date).any?
    if !existing_logs || rerun
      days.each do |day|
        response = http_request(uri: 'http://0.0.0.0:4567/providers/example-provider/instance-costs',
                          headers: {'Project-Credentials' => {'PROJECT_NAME': 'dummy-project'}.inspect,
                          query: {'instance_ids' => instance_ids,
                                  'start_time' => day.to_time.to_i,
                                  'end_time' => (day + 1).to_time.to_i}
                         )
        instance_data = JSON.parse(response)['usages']
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
    valid = true
    begin
      @explorer.get_cost_and_usage(total_cost_query(Project::DEFAULT_COSTS_DATE)).results_by_time
    rescue => error
      puts "Unable to obtain costs data: #{error}"
      valid = false
    end
    valid
  end
end
