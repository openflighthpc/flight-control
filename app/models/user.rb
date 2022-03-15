class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :rememberable, :validatable

  has_many :user_roles
  alias :roles :user_roles

  validates :username,
    presence: true,
    uniqueness: true

  validates :admin,
    inclusion: { within: [true, false] }

  before_save :default_values

  # Not all users have an email
  def email_required?
    false
  end

  def email_changed?
    false
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
    Project.where(id: user_roles.pluck(&:project_id))
  end

  def has_role_for?(project, role=nil)
    user_roles.exists?({project_id: project, role: role}.compact)
  end

  private

  def default_values
    self.admin = false if self.admin.nil?
  end
end
