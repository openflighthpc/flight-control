class SessionsController < Devise::SessionsController
  def new
    super
  end

  def about
    get_project if current_user
    @nav_view = "about"
  end

  def destroy
    super
    cookies.delete Rails.application.config.sso_cookie_name.to_sym, domain: :all
  end
end
