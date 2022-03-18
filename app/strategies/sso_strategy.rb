class SsoStrategy < Warden::Strategies::Base
  def valid?
    false
  end

  def authenticate!
    false
  end

  private

end
