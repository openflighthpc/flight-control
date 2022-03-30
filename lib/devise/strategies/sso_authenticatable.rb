require 'devise/strategies/authenticatable'

module Devise::Strategies
  class SsoAuthenticatable < Authenticatable

    def authenticate!
      uri = Rails.application.config.sso_uri
      uri = URI(uri)

      req = Net::HTTP::Post.new(uri.path)
      req.content_type = "application/json"
      body = {
        "account" => {
          "login" => params['user']['username'],
          "password" => params['user']['password']
        }
      }.to_json

      req.body = body

      use_ssl = Rails.application.config.use_ssl

      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: use_ssl) do |http|
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
