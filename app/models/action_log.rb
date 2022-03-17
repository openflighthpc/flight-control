class ActionLog < ApplicationRecord
  before_create :set_defaults
  belongs_to :project
  belongs_to :change_request, optional: true
  default_scope { order(:actioned_at) }
  validates :project_id, :reason, :instance_id, presence: true
  validates :created_at, :updated_at, presence: true, on: :save
  validates :action,
    presence: true,
    inclusion: {
      in: %w(on off),
      message: "must be 'on' or 'off'"
    }
  validate :valid_instance, on: :create
  #validate :automated_or_user

  def instance_log
    if !@instance_log
      @instance_log = InstanceLog.where(project_id: project_id).where(
                    instance_id: instance_id).where(
                    "created_at < ? ", actioned_at).last
      @instance_log ||= InstanceLog.where(project_id: project_id).where(
                    instance_id: instance_id).last
    end
    @instance_log
  end

  def instance_name
    instance_log.instance_name
  end

  def customer_facing_type
    instance_log.customer_facing_type
  end

  def compute_group
    instance_log.compute_group
  end

  # for use by audit log list
  def includes_group?(group)
    compute_group == group
  end

  def instance_type
    instance_log.instance_type
  end

  def front_end_instance_type
    instance_log.front_end_instance_type
  end

  # def partial
  #   :action_log_card
  # end

  def automated?
    automated == 1
  end

  def formatted_timestamp
    actioned_at.strftime('%-I:%M%P %F')
  end

  # def username
  #   user_id ? user.username : "Automated"
  # end

  def card_description
    html = "Started switch #{self.action} of 1 #{customer_facing_type}"
    html << detail_tooltip
    html << " in group #{compute_group}. "
    html << "<strong>Reason:</strong> #{reason}"
    html
  end

  def simplified_description
    "1 #{compute_group} #{customer_facing_type} #{action}#{detail_tooltip}"
  end

  def detail_tooltip
    "<a href='#'' class='tool-tip' data-placement='top' title='Instance name: #{instance_name}' onClick='return false;'><sup>?</sup></a>"
  end

  # def reason_with_link
  #   return self.reason if !scheduled_request_id

  #   "<a href='/scheduled-requests/#{scheduled_request_id}'>#{self.reason}</a>"
  # end

  def as_json(options={})
    {
      id: id,
      type: "action_log",
      timestamp: created_at,
      formatted_timestamp: formatted_timestamp,
      details: card_description,
      simplified_details: simplified_description,
      username: "Someone",
      automated: automated?,
      status: status
    }
  end

  def to_json(*options)
    as_json(*options).to_json(*options)
  end

  def same_action_as_latest_actual?
    latest = project.latest_instance_logs.where(instance_id: instance_id).last
    return nil if !latest

    (action == "on" && latest.status == InstanceLog::ON_STATUSES[project.platform]) ||
    (action == "off" && latest.status == InstanceLog::OFF_STATUSES[project.platform])
  end

  def check_and_update_status
    if !@checked
      @checked = true
      return status if status != "pending"

      goal = action == "on" ? "status = 'VM running' OR status = 'running'"  : "NOT status = 'VM running' AND NOT status = 'running'"
      reached = project.latest_instance_logs.where(instance_id: instance_id).where(goal).where('updated_at > ?', actioned_at).any?
      complete if reached
      status
    else
      status
    end
  end

  def complete
    self.status = "completed"
    save!

    complete_previous
  end

  def has_next?
    ActionLog.where(instance_id: instance_id).where("id > ?", id).any?
  end

  # if a previous action for the same instance that is still pending, we can assume it has completed
  # (but no instance log/ check between then and now)
  def complete_previous
    ActionLog.where(instance_id: instance_id).where(status: "pending").where(
                    "id < ?", id).update_all(status: "completed")
  end

  private

  def valid_instance
    instance = InstanceLog.where(project_id: project_id).where(instance_id: instance_id).any?
    errors.add(:instance_name, "not found for that project") if !instance
  end

  def set_defaults
    self.status = "pending"
    self.actioned_at ||= Time.now
    self.date = self.actioned_at.to_date
  end

  # def automated_or_user
  #   if !automated? && !user_id
  #     errors.add(:user_id, "must not be blank if not an automated change")
  #   end
  # end
end
