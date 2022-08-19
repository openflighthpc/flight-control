class ApplicationController < ActionController::Base
  include Pundit::Authorization
  protect_from_forgery
  before_action :authenticate_user_from_jwt!, :authenticate_user!

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  def get_project
    @project = current_user.projects.find_by_name(params['project_name'])
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

  def check_missing_instance_details
    if @project.missing_instance_details?
      flash.now[:danger] = @project.missing_instance_details_flash
    end
  end

  private

  def authenticate_user_from_jwt!
    existing_session = User.find_by(id: session["warden.user.user.key".to_sym]&.[](0))
    return if existing_session && !existing_session.sso?

    token = cookies[Rails.application.config.sso_cookie_name.to_sym]
    if existing_session&.sso? && token.blank?
      sign_out existing_session
    end
    return if token.blank?

    user = User.from_jwt_token(token)
    return if !user
    return if user == existing_session
    sign_in_and_redirect user
  end

  def user_not_authorized
    flash[:alert] = "You are not authorised to perform this action."
    redirect_to(request.referrer || authenticated_root_path)
  end
end
