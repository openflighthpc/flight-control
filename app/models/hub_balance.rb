require_relative 'project'

class HubBalance < ApplicationRecord
  belongs_to :project
  validates :amount, :effective_at, :project_id, presence: true
  validates :amount, numericality: { greater_than_or_equal_to: 0 }
  default_scope { order(:effective_at, :created_at) }

  def description
    result = self.valid? ? "" : "not "
    msg = "Hub Balance *#{result}saved* for project *#{project.name}*:\n\n"
    msg << "*Amount*: #{amount}c.u.\n"
    msg << "*Errors*: #{request_errors}\n" if !self.valid?
    msg
  end
end
