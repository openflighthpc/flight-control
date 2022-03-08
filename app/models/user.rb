class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :rememberable, :validatable

  validates :username,
    presence: true,
    uniqueness: true

  # Not all users have an email
  def email_required?
    false
  end

  def email_changed?
    false
  end

  def active_for_authentication?
    super && !archived?
  end

  def archived?
    archived_at&.<= Time.current
  end

  def active?
    !archived?
  end

  # User#archive takes an argument in case we want
  # to schedule an archival date
  def archive(time: Time.current)
    update(archived_at: time)
  end

  def activate
    update(archived_at: nil)
  end
end
