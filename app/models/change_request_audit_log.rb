class ChangeRequestAuditLog < ApplicationRecord
  AUDITED_ATTRIBUTES=%w[counts time date type monitor_override_hours status weekdays formatted_days end_date]
  PRETTIFIED_ATTRIBUTES={"time" => "Start time", "date" => "Start date", "monitor_override_hours" => "Override monitor for",
                         "formatted_days" => "Days", "end_date" => "End date"
                        }
  UNSHOWN_ATTRIBUTES=%w[weekdays type]
  belongs_to :project
  belongs_to :change_request
  belongs_to :user
  validates :project_id, :user_id, :change_request_id, :updates, :date, presence: true
  validate :includes_change, on: :create
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

  def changed_attributes
    changed = []
    updates["from"].each do |key, value|
      changed << key if value != updates["to"][key]
    end
    changed
  end

  def includes_group?(group)
    change_request.includes_group?(group)
  end

  private

  def set_updates
    { from: @original_attributes, to: @new_attributes }
  end

  def includes_change
    if !changed_attributes.any?
      errors.add(:log, "must include a change")
    end
  end
end
