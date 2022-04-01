class SessionsController < Devise::SessionsController
  def new
    super
  end

  def destroy
    super
    cookies.delete Rails.application.config.sso_cookie_name, domain: :all
  end
end
