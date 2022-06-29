class ProjectsController < ApplicationController
  def dashboard
    get_project
    if !@project
      no_project_redirect
    else
      authorize @project, policy_class: ProjectPolicy
    end
    @nav_view = "dashboard"
    get_billing_data
    get_upcoming_events
    get_group_data
  end

  def costs_breakdown
    get_project
    if !@project
      no_project_redirect
    else
      authorize @project, policy_class: ProjectPolicy
      @nav_view = "costs"
      get_costs_data
    end
  end

  def policy_page
    get_project
    if !@project
      no_project_redirect
    else
      authorize @project, policy_class: ProjectPolicy
      @nav_view = "policies"
    end
  end

  def audit
    get_project
    if !@project
      no_project_redirect
    else
      authorize @project, policy_class: ProjectPolicy
      @list = AuditLogList.new(@project, params)
      @nav_view = "audit"
    end
  end

  def audit_logs
    get_project
    if !@project
      no_project_redirect
    else
      authorize @project, policy_class: ProjectPolicy
      latest_timestamp = Time.parse(params['timestamp'])
      log_count = params['log_count'].to_i
      filters = {"groups" => params['groups'],
                 "types" => params['types'],
                 "users" => params['users'],
                 "statuses" => params['statuses'],
                 "start_date" => params["start_date"],
                 "end_date" => params["end_date"]
                }
      list = AuditLogList.new(@project, filters)
      logs, more = list.next_logs(log_count, latest_timestamp)
      render json: {logs: logs, more: more}
    end
  end

  def config_update
    get_project
    if !@project
      no_project_redirect
    else
      authorize @project, policy_class: ProjectPolicy
      details = params.permit(config: {})["config"]
      result = @project.submit_config_change(details, current_user)
      if result.valid? && result.persisted?
        flash[:success] = "Config change submitted"
      else
        flash[:danger] = result.errors.full_messages.join(", ")
      end
      redirect_to policies_path(project: @project.name)
    end
  end

  def billing_management
    get_project
    if !@project
      no_project_redirect
    else
      @nav_view = "billing"
      authorize @project, policy_class: ProjectPolicy
      get_billing_data
      @billing_cycles = cost_plotter.historic_cycle_details
    end
  end

  def data_check
    get_project
    if !@project
      no_project_redirect
    else
      authorize @project, policy_class: ProjectPolicy
      timestamp = Time.parse(params['timestamp'])
      render json: {changed: @project.data_changed?(timestamp)}
    end
  end

  def get_billing_data
    @policy = @project.budget_policies.last
    @billing_date = cost_plotter.billing_date
    @latest_cycle_details = cost_plotter.latest_cycle_details
  end

  def get_upcoming_events
    @sorted_events = @project.events_by_date(@project.events)
                             .first(5)
                             .to_h
  end

  def get_group_data
    compute_groups = @project.front_end_compute_groups.keys
    @group_costs = cost_plotter.total_costs_this_cycle( ['core'] + compute_groups )
    @nodes_up = @project.nodes_up
  end

  def get_costs_data
    if params['start_date'] && params['start_date'] != ""
      @start_date = Date.parse(params['start_date'])
    else
      @start_date = cost_plotter.start_of_billing_interval(Date.today)
    end
    if params['end_date'] && params['end_date'] != ""
      @end_date = Date.parse(params['end_date'])
    else
      @end_date = cost_plotter.end_of_billing_interval(@start_date)
    end
    costs = cost_plotter.combined_cost_breakdown(@start_date, @end_date, nil, true)
    @cost_breakdown = cost_plotter.chart_cost_breakdown(@start_date, @end_date, nil, costs)
    @cumulative_costs = cost_plotter.chart_cumulative_costs(@start_date, @end_date, nil, costs)
    @possible_datasets = cost_plotter.possible_datasets
    @datasets = params['datasets']
    @current_instances = @project.latest_instances
    @cycle_thresholds = cost_plotter.cycle_thresholds(@start_date, @end_date)
    @min_date = cost_plotter.minimum_date
    @max_date = cost_plotter.date_limit
    @switch_offs = cost_plotter.front_end_switch_offs_by_date(@start_date, @end_date, false)
    @estimated_end_of_balance = cost_plotter.estimated_balance_end_in_cycle(@start_date, @end_date, costs)
    filter_current_instances if @datasets
  end

  private

  # Only include filtered groups, or all if none selected
  def filter_current_instances
    original = @current_instances.clone
    @current_instances.select! { |group, instances| @datasets.include?(group) }
    @current_instances = original if @current_instances.empty?
  end

  def cost_plotter
    @cost_plotter ||= CostsPlotter.new(@project)
  end

  def no_project_redirect
    render "projects/no_project"
  end
end
