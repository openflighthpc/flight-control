class ProjectsController < ApplicationController
  def costs_breakdown
    get_costs_data
  end

  def data_check
    @project = Project.find_by_name(params['project'])
    @project ||= Project.first
    timestamp = Time.parse(params['timestamp'])
    render json: {changed: @project.data_changed?(timestamp)}
  end

  def get_costs_data
    @project = Project.find_by_name(params['project'])
    @project ||= Project.first
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
    @cost_breakdown = cost_plotter.chart_cost_breakdown(@start_date, @end_date)
    @cumulative_costs = cost_plotter.chart_cumulative_costs(@start_date, @end_date)
    @possible_datasets = cost_plotter.possible_datasets
    @datasets = params['datasets']
    @current_instances = @project.latest_instances
    filter_current_instances if @datasets
  end

  # Only include filtered groups, or all if none selected
  def filter_current_instances
    original = @current_instances.clone
    @current_instances.select! { |group, instances| @datasets.include?(group) }
    @current_instances = original if @current_instances.empty?
  end
end
