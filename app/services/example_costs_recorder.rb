require_relative '../models/example_project'
require_relative '../models/cost_log'

class ExampleCostsRecorder

  def initialize(project)
    @project = project
  end

  def record_logs(start_date, end_date=start_date, rerun=false, verbose=false)

    instance_ids = http_request(uri: 'http://0.0.0.0:4567/providers/example-provider/instances',
                                headers: {'Project-Credentials' => {'PROJECT_NAME': 'dummy-project'}.inspect,
                               ).map { |instance| instance['instance_id'] }
    response = http_request(uri: 'http://0.0.0.0:4567/providers/example-provider/instance-costs',
                            headers: {'Project-Credentials' => {'PROJECT_NAME': 'dummy-project'}.inspect,
                            query: {'instance_ids' => instance_ids,
                                    'start_time' => start_date,
                                    'end_time' => end_date}
                           )
    all_costs = JSON.parse(response)['usages']
  end

  # in the future will have option to create for multiple days at once
  def record_costs(start_date, end_date, rerun, verbose, scope, compute_group=nil)
    log = @project.cost_logs.find_by(date: start_date, scope: scope)
    if !log || rerun
      if compute_group
        storage = scope.include?("storage")
        cost_query = self.send("compute_group_cost_query", start_date, end_date, compute_group, storage)
      else
        cost_query = self.send("#{scope}_cost_query", start_date, end_date)
      end
      begin
        response = @explorer.get_cost_and_usage(cost_query).results_by_time
      rescue Aws::CostExplorer::Errors::ServiceError, Seahorse::Client::NetworkingError => error
        raise AwsSdkError.new("Unable to determine core costs for project #{@project.name}. #{error if verbose}") 
      end
      # for daily report will just be one day, but multiple when run for a range
      response.each do |day|
        date = day[:time_period][:start]
        cost = day[:total]["UnblendedCost"][:amount].to_f
        log = @project.cost_logs.find_by(date: date, scope: scope)
        if rerun && log
          log.assign_attributes(cost: cost)
          log.save!
        else
          log = CostLog.create(
            project_id: @project.id,
            cost: cost,
            currency: "USD",
            compute: compute_group.present?,
            date: date,
            scope: scope
          )
        end
      end
    end
    log
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

  private

  # instance costs or storage costs
  def compute_group_cost_query(start_date, end_date=(start_date + 1), group, storage)
    query = total_cost_query(start_date, end_date)
    query[:filter][:and] << compute_filter
    if storage
      query[:filter][:and] << storage_filter
    else
      query[:filter][:and] += instance_run_cost_filter
    end
    query
  end

end
