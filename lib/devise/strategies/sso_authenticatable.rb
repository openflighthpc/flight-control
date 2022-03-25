require 'devise/strategies/authenticatable'

module Devise::Strategies
  class SsoAuthenticatable < Authenticatable

    def authenticate!
      url = Rails.application.config.sso_path["host"]
      port = Rails.application.config.sso_path["port"]
      uri = URI.parse(url)

      req = Net::HTTP::Post.new(uri)
      req.content_type = "application/json"
      req.body = JSON.dump({
        "account" => {
          "login" => params['user']['username'],
          "password" => params['user']['password']
        }
      })

      res = Net::HTTP.start(uri.hostname, port) do |http|
        http.request(req)
      end

      begin
        res = JSON.parse(res.body)
        user = User.from_jwt_token(res['user']['authentication_token'])
        cookie = Rails.application.config.sso_cookie_name
        cookies[cookie.to_sym] = res['user']['authentication_token']
        success!(user)
      rescue JSON::ParserError
        fail(message = "Invalid Username or password.")
      end
    end
  end
end

Warden::Strategies.add(:sso_authenticatable, Devise::Strategies::SsoAuthenticatable)
