class ConfigLog < ActiveRecord::Base
  belongs_to :project
  belongs_to :user
  belongs_to :change_request, optional: true
  default_scope { order(:created_at) }
  validates :project_id, presence: true
  validates :config_changes, presence: true, on: :save
  validate :includes_change, on: :create
  validate :automated_or_user
  validate :override_null_or_valid_time, on: :create

  def details=(details)
    existing_override = project.override_monitor_until if project.override_monitor_until
    new_override = details["override_monitor_until"]
    new_override = nil if new_override == ""
    if new_override != nil && valid_time?(new_override)
      new_override = Time.parse(new_override).strftime("%Y/%m/%d %H:%M:%S %z")
    end
    monitor_details = {from: existing_override, to: new_override}
    if self.automated
       full_details = {override_monitor_until: monitor_details}
    else
      full_details = {
                      monitor_active: {},
                      override_monitor_until: monitor_details,
                      utilisation_threshold: {}
                     }
      full_details[:monitor_active][:from] = self.project.monitor_active?
      full_details[:monitor_active][:to] = details['monitor_active'] == 'true'
      full_details[:utilisation_threshold][:from] = self.project.utilisation_threshold
      if details['monitor_active'] != 'true'
        full_details[:utilisation_threshold][:to] = full_details[:utilisation_threshold][:from]
      else
        full_details[:utilisation_threshold][:to] = details["utilisation_threshold"].to_i
      end
    end
    self.config_changes = full_details
  end

  def formatted_timestamp
    created_at.strftime('%-I:%M%P %F')
  end

  def formatted_changes
    if automated
      message ="The configuration of project *#{self.project.name}* has been updated as part of a scheduled request:\n"
    else
      message ="#{self.user.username} has updated the configuration of project *#{self.project.name}*:\n"
    end
    # currently just monitor override time, but more will be possible in future
    config_changes.each do |attribute, details|
      if details["to"] != details["from"]
        details["to"] = "none" if details["to"].blank?
        attribute = "*#{attribute.gsub("_", " ").capitalize}*"
        message << "#{attribute}: #{details["to"]}\n"
      end
    end
    message
  end

  # Not currently used
  def card_description
    ""
    # html = "Project configuration updated:<br><br>"
    # html << "<div class='change-details'>"
    # parsed_changes.each do |attribute, details|
    #   if details["to"] != details["from"]
    #     if attribute == 'compute_groups'
    #       html << "<strong>Instance priorities:</strong>"
    #     else
    #       html << "<strong>#{attribute.gsub("_", " ").capitalize}:</strong>"
    #     end
    #     details["to"] = "none (monitor enabled)" if details["to"].nil?
    #     if attribute == 'compute_groups'
    #       html << "<br>"
    #       out_str = ""
    #       details['to'].each do |group, g_details|
    #         out_str << "#{group}:\n"
    #         g_details['nodes'].each do |node, n_details|
    #           out_str << "  #{InstanceMapping.opposite_name(node)}\n"
    #         end
    #       end
    #       out_str.gsub!(' ', '&nbsp;').gsub!("\n", '<br>')
    #       html << out_str
    #     else
    #       html << " #{details["to"]}"
    #       html << "%" if attribute == "utilisation_threshold"
    #     end
    #     html << "<br>"
    #   end
    # end
    # html << "</div>"
    # html
  end

  def status
    "completed"
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
    config_changes.each do |key, value|
      return true if value["from"] != value["to"]
    end

    errors.add(:changes, "must involve a config change")
  end

  def override_null_or_valid_time
    if config_changes["override_monitor_until"]
      override = config_changes["override_monitor_until"]["to"]
      errors.add(:override, "is an invalid time") if override && !valid_time?(override)
    end
  end

  def threshold_null_or_in_range
    if config_changes["utilisation_threshold"]
      utilisation_threshold = config_changes["utilisation_threshold"]["to"].to_i
      if !(1..10).include?(utilisation_threshold)
        errors.add(:threshold, "Must be between 1 and 10 (inclusive)")
      end
    end
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
