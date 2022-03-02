class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  validates :username,
    presence: true,
    uniqueness: true

  def email_required?
    false
  end

  def email_changed?
    false
  end
end
