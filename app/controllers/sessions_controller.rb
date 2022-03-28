class SessionsController < Devise::SessionsController
  def new
    super
  end

  def destroy
    cookies.delete Rails.application.config.sso_cookie_name
    super
  end
end
