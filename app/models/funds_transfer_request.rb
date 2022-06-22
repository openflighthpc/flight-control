class FundsTransferRequest < ApplicationRecord
  after_initialize :set_defaults
  belongs_to :project
  validates :project_id, :amount, :signed_amount, :reason, presence: true
  validates :amount, numericality: { greater_than_or_equal_to: 0 }
  validates :created_at, :updated_at, presence: true, on: :save
  validates :action,
    presence: true,
    inclusion: {
      in: %w(send receive),
      message: "must be 'send' or 'receive'"
    }
  default_scope { order(:created_at) }
  scope :completed, -> { where(status: "completed") }

  def completed?
    status == "completed"
  end

  def failed?
    status == "failed"
  end

  def not_enough_balance?
    failed? && request_errors.include?("exceeds the dept's balance")
  end

  def description
    msg = "Funds transfer request *#{status}* for project *#{project.name}*:\n\n"
    descriptive_action = action == "send" ? "Send #{amount}c.u. to" : "Receive #{amount}c.u. from"
    msg << "*Action*: #{descriptive_action} Flight Hub\n"
    msg << "*Reason*: #{reason}\n"
    msg << "*Errors*: #{request_errors}\n" if status == "failed"
    msg
  end

  private

  def set_defaults
    self.status ||= "submitted"
    self.date ||= Date.current
    self.signed_amount ||= self.action == "send" ? self.amount * -1 : self.amount
  end
end
