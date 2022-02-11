class EventsController < ApplicationController
  def new
    get_project
    @current_instances = @project.latest_instances
    @nav_view = "create event"
  end

  def create
    get_project
    render json: filtered_change_request_params.to_json
  end

  def filtered_change_request_params
    permitted = params.permit(
      :counts_criteria,
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
