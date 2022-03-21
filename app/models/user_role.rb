class UserRole < ApplicationRecord
  ROLES = %w( default viewer ).map(&:freeze).freeze
  ROLES.each do |r|
    const_set r.upcase, r
  end

  belongs_to :user
  belongs_to :project

  attr_accessor :skip_uniqueness

  ROLES.each do |r|
    scope r.pluralize, ->() { where(role: r) }
  end

  validates :role,
    uniqueness: { scope: [:project_id, :user_id] },
    unless: :skip_uniqueness

  validates :role,
    presence: true,
    inclusion: { within: ROLES }
end
