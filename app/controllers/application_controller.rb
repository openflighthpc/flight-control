class ApplicationController < ActionController::Base
  include Pundit::Authorization
  protect_from_forgery
  before_action :authenticate_user_from_jwt!, :authenticate_user!,
    :check_user_has_project!, :get_project!, :check_project_budget_status!

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

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

  def check_user_has_project!
    if current_user && current_user.projects.empty?
      render "projects/no_project"
    end
  end

  # This will need updating when we move to using /project/:id routes.
  def get_project!
    if current_user
      if params['project'].present?
        @project = current_user.projects.find_by_name(params['project'])
      else
        @project = current_user.projects.active.first
      end
    end
  end

  def check_project_budget_status!
    if current_user && @project && FundsManager.new(@project).pending_budget_updates?
      render "projects/pending_budget_updates"
    end
  end
end
