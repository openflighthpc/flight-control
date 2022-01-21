class ProjectsController < ApplicationController
  def costs_breakdown
    get_project_data
  end

  def get_project_data
    @project = Project.first
  end
end
