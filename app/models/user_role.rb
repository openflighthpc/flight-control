class UserRole < ApplicationRecord
  ROLES = %w( standard viewer ).map(&:freeze).freeze
  ROLES.each do |r|
    const_set r.upcase, r
  end

  belongs_to :user
  belongs_to :project

  ROLES.each do |r|
    scope r.pluralize, ->() { where(role: r) }
  end

  validates :role,
    presence: true,
    inclusion: { within: ROLES }
end
