class FundsTransferRequest < ApplicationRecord
  after_initialize :set_defaults
  belongs_to :project
  validates :project_id, :amount, :reason, presence: true
  validates :amount, numericality: { greater_than_or_equal_to: 0 }
  validates :created_at, :updated_at, presence: true, on: :save
  validates :action,
    presence: true,
    inclusion: {
      in: %w(send receive),
      message: "must be 'send' or 'receive'"
    }
  default_scope { order(:created_at) }

  private

  def set_defaults
    self.status = "submitted"
    self.date = Date.today
  end
end
