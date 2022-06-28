class FundsTransferRequest < ApplicationRecord
  after_initialize :set_defaults
  belongs_to :project
  validates :project_id, :date, :amount, :signed_amount, :reason, presence: true
  validates :amount, numericality: { greater_than_or_equal_to: 0 }
  validates :created_at, :updated_at, presence: true, on: :save
  validates :action,
    presence: true,
    inclusion: {
      in: %w(send receive),
      message: "must be 'send' or 'receive'"
    }
  default_scope { order(:date) }
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

  def partial
    'funds_transfer_request_card'
  end

  def description
    msg = "Funds transfer request *#{status}* for project *#{project.name}*:\n\n"
    descriptive_action = action == "send" ? "Send #{amount}c.u. to" : "Receive #{amount}c.u. from"
    msg << "*Action*: #{descriptive_action}\n"
    msg << "*Reason*: #{reason}\n"
    msg << "*Errors*: #{request_errors}\n" if failed?
    msg
  end

   def card_description
    html = "Funds transfer request submitted.<br><br>"
    html << "<div class='transfer-details'>"
    html << "<strong>Action:</strong> #{descriptive_action}<br>"
    html << "<strong>Reason:</strong> #{reason}<br>"
    if failed?
      html << "<strong>Errors:</strong> "
      html << "<span class='text-danger'>#{request_errors}</span><br>"
    end
    html << "</div>"
    html
  end

  def descriptive_action
    descriptive_action = action == "send" ? "Send #{amount}c.u. to" : "Receive #{amount}c.u. from"
    descriptive_action << " Flight Hub"
  end

  private

  def set_defaults
    self.status ||= "submitted"
    self.date ||= Date.current
    self.signed_amount ||= self.action == "send" ? self.amount * -1 : self.amount
  end
end
