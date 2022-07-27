require 'jwt'

class JsonWebToken
  def self.encode(payload, expiration = 24.hours.from_now)
    payload = payload.dup
    payload['exp'] = expiration.to_i
    JWT.encode(
      payload,
      Rails.configuration.jwt_secret,
      'HS256'
    )
  end

  def self.decode(token, options={})
    JWT.decode(
      token,
      Rails.configuration.jwt_secret,
      true,
      { algorithm: 'HS256' }.merge(options)
    ).first
  end
end
