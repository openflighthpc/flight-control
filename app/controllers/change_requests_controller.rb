class ChangeRequestsController < ApplicationController
  def manage
    get_project
    authorize ChangeRequest.new(project: @project)
    @compute_groups = @project.front_end_compute_groups.keys
    @filtered_groups = params[:groups]
    @current_instances = @project.latest_instances
    @in_progress = @project.pending_action_logs
    if @filtered_groups
      @in_progress = @in_progress.select { |log| @filtered_groups.include?(log.compute_group) }
    end
    @upcoming = @project.upcoming_events_by_date(@filtered_groups)
    @future_events = @project.future_events_by_date(@filtered_groups)
    filter_records if @filtered_groups
    @nav_view = "manage events"
    @editor = ChangeRequestPolicy.new(current_user, ChangeRequest.new(project: @project)).create?
  end

  def latest
    get_project
    authorize ChangeRequest.new(project: @project)
    render json: @project.current_events_data(params[:groups]).to_json({original: false})
  end

  def new
    get_project
    authorize ChangeRequest.new(project: @project)
    @current_instances = @project.latest_instances
    cost_plotter = CostsPlotter.new(@project)
    start_date = cost_plotter.start_of_billing_interval(Date.today)
    end_date = cost_plotter.end_of_billing_interval(start_date)
    @cycle_thresholds = cost_plotter.cycle_thresholds(start_date, end_date)
    @existing_timings = @project.request_dates_and_times
    @nav_view = "event wizard"
  end

  def edit
    get_project
    @request = ChangeRequest.find_by_id(params[:id])
    if !@request
      flash[:danger] = "Request not found"
    else
      authorize @request, policy_class: ChangeRequestPolicy
      if !@request.editable?
        flash[:danger] = "Cannot edit that request"
        redirect_to events_path
        return
      end
    end
    @current_instances = @project.latest_instances
    cost_plotter = CostsPlotter.new(@project)
    start_date = cost_plotter.start_of_billing_interval(Date.today)
    end_date = cost_plotter.end_of_billing_interval(Date.today)
    @cycle_thresholds = cost_plotter.cycle_thresholds(start_date, end_date)
    @existing_timings = @project.request_dates_and_times(@request)
    @nav_view = "event wizard"
    render :new
  end

  def create
    parameters = filtered_change_request_params
    @project = Project.find_by_name(parameters[:project])
    if !@project
      flash[:danger] = "Project not found"
    else
      authorize ChangeRequest.new(project: @project)
      parameters.delete(:project)
      parameters[:user_id] = current_user.id
      parameters[:over_budget_switch_offs] = parameters[:over_budget_switch_offs] == "true"
      request = @project.create_change_request(parameters)
      if request.valid?
        flash[:success] = "Request created"
      else
        flash[:danger] = format_errors(request)
      end
    end
    redirect_to events_path(project: @project.name)
  end

  def update
    get_project
    parameters = filtered_change_request_params
    request = ChangeRequest.find_by_id(params[:id])
    if !request
      flash[:danger] = "Request not found"
    else
      authorize request, policy_class: ChangeRequestPolicy
      if request.id != parameters[:id].to_i
        flash[:danger] = "Ids do not match"
      else
        if !request.editable?
          flash[:danger] = "Cannot edit that request"
        else
          parameters.delete(:project)
          parameters.delete(:timeframe)
          parameters[:over_budget_switch_offs] = parameters[:over_budget_switch_offs] == "true"
          request, success = @project.update_change_request(request, current_user, parameters)
          if success
            flash[:success] = "Request updated"
          else
            if !request.changed?
              flash[:danger] = "No changes made"
            elsif !request.valid?
              flash[:danger] = format_errors(request)
            end
          end
        end
      end
    end
    redirect_to events_path(project: @project.name)
  end

  def cancel
    get_project
    request = ChangeRequest.find_by_id(params[:id])
    if !request
      flash[:danger] = "Request not found"
    else
      authorize request, policy_class: ChangeRequestPolicy
      success = @project.cancel_change_request(request, current_user)
      if success
        flash[:success] = "Request cancelled"
      else
        flash[:danger] = "Unable to cancel request"
      end
    end
    redirect_to events_path(project: @project.name)
  end

  def costs_forecast
    parameters = filtered_change_request_params
    @project = Project.find_by_name(parameters[:project])
    authorize ChangeRequest.new(project: @project)
    render json: @project.change_request_cumulative_costs(parameters)
  end

  def filtered_change_request_params
    permitted = params.permit(
      :counts_criteria,
      :project,
      :id,
      :timeframe,
      :date,
      :time,
      :weekdays,
      :type,
      :end_date,
      :description,
      :monitor_override_hours,
      :over_budget_switch_offs,
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

  def filter_records
    return if !@filtered_groups
    filter_current_instances
    @in_progress.to_a.select! { |log| @filtered_groups.include?(log.compute_group) }
  end

  def filter_current_instances
    original = @current_instances.clone
    @current_instances = original.select { |group, instances| @filtered_groups.include?(group) }
    @current_instances = original if @current_instances.empty?
  end
end
