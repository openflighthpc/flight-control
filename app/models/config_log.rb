class ConfigLog < ApplicationRecord
  belongs_to :project
  belongs_to :user
  belongs_to :change_request, optional: true
  default_scope { order(:created_at) }
  validates :project_id, :type, presence: true
  validates :config_changes, presence: true, on: :save
  validate :includes_change, on: :create
  validate :automated_or_user

  def details=(details)
    self.config_changes = full_details(details)
  end

  # parse what has changed and how
  def full_details(details)
  end

  def formatted_changes
  end

  def partial
    'config_log_card'
  end

  def card_description
    html = "Project configuration updated:<br><br>"
    html << "<div class='change-details'>"
    html << card_details
    html << "</div>"
    html
  end

  def status
    "completed"
  end

  def card_details
  end

  def as_json(options={})
    {
      type: "config_log",
      username: automated ? "System" : user.username,
      automated: automated,
      change_request_id: change_request_id,
      timestamp: created_at,
      formatted_timestamp: formatted_timestamp,
      details: card_description,
      status: status
    }
  end

  def to_json(*options)
    as_json(*options).to_json(*options)
  end

  private

  def includes_change
  end

  def valid_time?(time_string)
    begin
      time = Time.parse(time_string)
    rescue ArgumentError
      return false
    end
    true
  end

  def automated_or_user
    if !automated && !user_id
      errors.add(:user_id, "must not be blank if not an automated change")
    end
  end
end
