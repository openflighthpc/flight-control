class ProjectsController < ApplicationController
  def costs_breakdown
    @nav_view = "costs"
    get_costs_data
  end

  def billing_management
    @nav_view = "billing"
    get_project
    cost_plotter = CostsPlotter.new(@project)
    @billing_cycles = cost_plotter.historic_cycle_details
    @policy = @project.budget_policies.last
    @billing_date = cost_plotter.billing_date
    @latest_cycle_details = cost_plotter.latest_cycle_details
  end

  def data_check
    get_project
    timestamp = Time.parse(params['timestamp'])
    render json: {changed: @project.data_changed?(timestamp)}
  end

  def get_costs_data
    get_project
    cost_plotter = CostsPlotter.new(@project)
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
    costs = cost_plotter.cost_breakdown(@start_date, @end_date)
    @cost_breakdown = cost_plotter.chart_cost_breakdown(@start_date, @end_date, nil, costs)
    @cumulative_costs = cost_plotter.chart_cumulative_costs(@start_date, @end_date, nil, costs)
    @possible_datasets = cost_plotter.possible_datasets
    @datasets = params['datasets']
    @current_instances = @project.latest_instances
    filter_current_instances if @datasets
    @cycle_thresholds = cost_plotter.cycle_thresholds(@start_date, @end_date)
    @estimated_end_of_balance = cost_plotter.estimated_balance_end_in_cycle(@start_date, @end_date)
  end

  # Only include filtered groups, or all if none selected
  def filter_current_instances
    original = @current_instances.clone
    @current_instances.select! { |group, instances| @datasets.include?(group) }
    @current_instances = original if @current_instances.empty?
  end
end
