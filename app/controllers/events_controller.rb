class EventsController < ApplicationController
  def new
    get_project
    @nav_view = "create event"
  end
end
