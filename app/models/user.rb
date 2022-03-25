require 'json_web_token'

class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :sso_authenticatable, :rememberable, :validatable

  has_many :change_requests
  has_many :change_request_audit_logs
  has_many :action_logs
  has_many :user_roles, dependent: :delete_all
  alias :roles :user_roles

  validates :username,
    presence: true,
    uniqueness: true

  validates :admin,
    inclusion: { within: [true, false] }

  validates :flight_id,
    uniqueness: true

  before_save :default_values

  def self.from_jwt_token(token, jwt_decode_options={})
    claims = ::JsonWebToken.decode(token, jwt_decode_options)
    # Attempt to find user by `flight_id`
    user = find_by(flight_id: claims.fetch('flight_id'))
    if user.present?
      user.jwt_iat = claims.fetch('iat')
      user.save
      return user
    else
      # No user with given `flight_id`. This is most likely the first
      # time that a user is accessing Flight Control. Check if the user's
      # email exists in the DB, and if not, create the user.
      user = User.find_by_email(claims.fetch('email') || User.new(
        username: claims.fetch('username'),
        email: claims.fetch('email'),
        flight_id: claims.fetch('flight_id'),
        password: SecureRandom.base58(20)
      )

      if user.save
        return user
      else
        raise user.errors.full_messages.to_s
      end
    end
  end

  # Not all users have an email
  def email_required?
    false
  end

  def email_changed?
    false
  end

  def sso?
    flight_id.present?
  end

  # Override base Devise method to include an archived? check
  def active_for_authentication?
    super && !archived?
  end

  # Use of Time.current should be consistent. When time zones are set,
  # it uses the given time zone. Otherwise, it returns Time.now.
  def archived?
    archived_at&.<= Time.current
  end

  def active?
    !archived?
  end

  # User#archive takes an argument in case we want
  # to schedule an archival date
  def archive(time=Time.current)
    update(archived_at: time)
  end

  def activate
    update(archived_at: nil)
  end

  def projects
    (admin? ? Project.all : Project.where(id: user_roles.map(&:project_id))).reorder(:name)
  end

  def multi_project_user?
    @multi ||= projects.length > 1
  end

  def has_role_for?(project, role=nil)
    user_roles.exists?({project_id: project, role: role}.compact)
  end

  private

  def default_values
    self.admin = false if self.admin.nil?
  end
end
