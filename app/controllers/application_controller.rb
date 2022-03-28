class ApplicationController < ActionController::Base
  include Pundit::Authorization
  protect_from_forgery
  prepend_before_action :authenticate_user_from_jwt!
  before_action :authenticate_user!

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  def get_project
    @project = current_user.projects.find_by_name(params['project'])
    @project ||= current_user.projects.visualiser.active.first
  end

  def format_errors(model)
    model.errors.messages.map do |field, messages|
      "#{format_errors_field(field).to_s.humanize} #{messages.join(', ')}"
    end.join('; ')
  end

  def format_errors_field(field)
    field.to_s.split('.').map { |f| f.singularize.humanize }.join(' ')
  end

  private

  def authenticate_user_from_jwt!
    return if cookies['_flight_control_session'.to_sym]
    token = cookies[Rails.application.config.sso_cookie_name.to_sym]
    return if token.blank?
    user = User.from_jwt_token(token)
    return if !user
    sign_in user
  end

  def user_not_authorized
    flash[:alert] = "You are not authorised to perform this action."
    redirect_to(request.referrer || authenticated_root_path)
  end
end
