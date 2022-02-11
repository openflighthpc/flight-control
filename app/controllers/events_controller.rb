class EventsController < ApplicationController
  def new
    get_project
    @current_instances = @project.latest_instances
    @nav_view = "create event"
  end

  def create
    parameters = filtered_change_request_params
    @project = Project.find_by_name(parameters[:project])
    if !@project
      flash[:danger] = "Project not found"
      redirect_to events_new_path
    else
      render json: parameters.to_json
    end
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
