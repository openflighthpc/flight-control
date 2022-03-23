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
      raise res.body.to_s

      fail! res.to_s.html_safe
    end
  end
end

Warden::Strategies.add(:sso_authenticatable, Devise::Strategies::SsoAuthenticatable)
