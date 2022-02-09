class EventsController < ApplicationController
  def new
    get_project
    @current_instances = @project.latest_instances
    @nav_view = "create event"
  end
end
