namespace :sso do
  desc 'Sync changes to SSO accounts to Flight Control users'
  task sync: :environment do
    require 'open-uri'
    require 'json_web_token'

    jwt = JsonWebToken.encode(
      {
        iss: 'Alces Flight Center',
        aud: 'Flight SSO',
      },
      5.minutes.from_now
    )
    uri = URI(Rails.application.config.sso_uri)
    uri.path << "/accounts"
    Rails.logger.info("Retrieving SSO tokens from #{uri.to_s}")
    uri.query = URI.encode_www_form(
      URI.decode_www_form(uri.query || '') << ["token", jwt]
    )
    body = URI.open(uri.to_s).read
    unless body.empty?
      tokens = JSON.parse(body)['tokens']
      Rails.logger.info("Syncing #{tokens.length} SSO tokens")
      tokens.each do |token|
        User.from_jwt_token(token, verify_expiration: false)
      end
    end
  end
end
