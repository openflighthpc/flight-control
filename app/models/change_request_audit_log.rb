class ChangeRequestAuditLog < ApplicationRecord
  AUDITED_ATTRIBUTES=%w[counts time date type monitor_override status weekdays formatted_days end_date]
  PRETTIFIED_ATTRIBUTES={"time" => "Start time", "date" => "Start date", "monitor_override" => "Override monitor for",
                         "formatted_days" => "Days", "end_date" => "End date"
                        }
  UNSHOWN_ATTRIBUTES=%w[weekdays type]
  belongs_to :project
  belongs_to :change_request
  validates :project_id, :change_request_id, :updates, :date, presence: true
  default_scope { order(:created_at) }

  after_initialize do |change_request|
    self.updates ||= set_updates
  end

  def original_attributes=(original)
    @original_attributes = original.select { |key, value| AUDITED_ATTRIBUTES.include?(key) }
  end

  def new_attributes=(current)
    @new_attributes = current.select { |key, value| AUDITED_ATTRIBUTES.include?(key) }
  end

  private

  def set_updates
    { from: @original_attributes, to: @new_attributes }
  end
end
