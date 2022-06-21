class SessionsController < Devise::SessionsController
  skip_before_action  :check_user_has_project!, :get_project!, :check_project_budget_status!

  def new
    super
  end

  def destroy
    super
    cookies.delete Rails.application.config.sso_cookie_name.to_sym, domain: :all
  end
end
