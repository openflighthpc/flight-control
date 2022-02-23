class EventsController < ApplicationController
  def manage
    get_project
    @current_instances = @project.latest_instances
    @in_progress = @project.pending_action_logs
    @upcoming = @project.upcoming_events_by_date
    @future = @project.future_events_by_date
    @nav_view = "manage events"
  end

  def new
    get_project
    @current_instances = @project.latest_instances
    cost_plotter = CostsPlotter.new(@project)
    start_date = cost_plotter.start_of_billing_interval(Date.today)
    end_date = cost_plotter.end_of_billing_interval(start_date)
    @cycle_thresholds = cost_plotter.cycle_thresholds(start_date, end_date)
    @existing_timings = @project.request_dates_and_times
    @nav_view = "create event"
  end

  def create
    parameters = filtered_change_request_params
    @project = Project.find_by_name(parameters[:project])
    if !@project
      flash[:danger] = "Project not found"
    else
      parameters.delete(:project)
      request = @project.create_change_request(parameters)
      if request.valid?
        flash[:success] = "Request created"
      else
        flash[:danger] = format_errors(request)
      end
    end
    redirect_to events_new_path(project: @project.name)
  end

  def costs_forecast
    parameters = filtered_change_request_params
    @project = Project.find_by_name(parameters[:project])
    render json: @project.change_request_cumulative_costs(parameters)
  end

  def filtered_change_request_params
    permitted = params.permit(
      :counts_criteria,
      :project,
      :timeframe,
      :date,
      :time,
      :weekdays,
      :type,
      :end_date,
      :description,
      nodes: {}
    )
    filtered = permitted.transform_values do |value|
      # filter hash within params
      if value.class == ActionController::Parameters
        value.select { |k, v| v != "" }
      else
        value == "" ? nil : value
      end
    end
  end
end
