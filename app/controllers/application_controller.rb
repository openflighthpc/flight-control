class ApplicationController < ActionController::Base
  def get_project
    @project = Project.find_by_name(params['project'])
    @project ||= Project.visualiser.first
  end
end
