class EventsController < ApplicationController
  def new
    get_project
    @current_instances = @project.latest_instances
    @nav_view = "create event"
  end

  def create
    get_project
    render json: params.to_json
  end
end
