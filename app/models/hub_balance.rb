require_relative 'project'

class HubBalance < ApplicationRecord
  belongs_to :project
  validates :amount, :effective_at, :project_id, presence: true
  validates :amount, numericality: { greater_than_or_equal_to: 0 }
  default_scope { order(:effective_at, :created_at) }
end
