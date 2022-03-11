class ApplicationController < ActionController::Base
  protect_from_forgery
  before_action :authenticate_user!

  def get_project
    @project = Project.find_by_name(params['project'])
    @project ||= current_user.projects.visualiser.first
  end

  def format_errors(model)
    model.errors.messages.map do |field, messages|
      "#{format_errors_field(field).to_s.humanize} #{messages.join(', ')}"
    end.join('; ')
  end

  def format_errors_field(field)
    field.to_s.split('.').map { |f| f.singularize.humanize }.join(' ')
  end
end
