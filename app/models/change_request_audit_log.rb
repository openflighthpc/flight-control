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

  def cancellation?
    updates["to"]["status"] == "cancelled"
  end

  def original_date_time
    if updates["from"]["date"]
      Time.parse("#{updates["from"]["date"]} #{updates["from"]["time"]}")
    else
      change_request.date_time
    end
  end

  def original_attributes
    original = Project.deep_copy_hash(updates["from"])
    original.delete("formatted_days")
    original.delete("status")
    original
  end

  def partial
    'change_request_audit_log_card'
  end

  def link_to_request
    if change_request.editable?
      "<a href='/events/#{change_request_id}/edit?project=#{project.name}'>change request</a>"
    else
      "change request"
    end
  end

  def card_description
    return "Cancelled the #{link_to_request} scheduled for #{change_request.date_time}" if cancellation?

    html = "Made the following changes to the #{link_to_request} previously scheduled for #{original_date_time}:<br><br>"
    html << "<div class='change-details'>"
    changed_attributes.each do |attribute|
      if attribute == "counts"
        html << count_changes_description
      elsif !UNSHOWN_ATTRIBUTES.include?(attribute) # save but don't show some data types that would confuse end user
        html << "<strong>#{PRETTIFIED_ATTRIBUTES[attribute]}</strong>: "
        html << "<del>#{updates["from"][attribute]}</del> "
        html << "#{updates["to"][attribute]}"
        html << " hour(s)" if attribute == "monitor_override"
        html << "<br>"
      end
    end
    html << "</div>"
    html
  end

  def count_changes_description
    original_counts = updates["from"]["counts"]
    new_counts = updates["to"]["counts"]
    return if !new_counts || original_counts == new_counts

    # from or to may have null values for groups and instance types,
    # so need to determine them all
    included_groups_and_types = {}
    (original_counts.keys | new_counts.keys).each do |group|
      if original_counts[group] != new_counts[group]
        included_groups_and_types[group] = {}
        types = (original_counts[group] ? original_counts[group].keys : []) |
                (new_counts[group] ? new_counts[group].keys : [])
        types.each do |type|
          from = original_counts[group] ? original_counts[group][type] : nil
          to = new_counts[group] ? new_counts[group][type] : nil
          included_groups_and_types[group][type] = {from: from, to: to} if from != to
        end
      end
    end

    html = "Count changes:<br>"

    included_groups_and_types.each do |group, details|
      html << "<strong>#{group}</strong><br>"
      details.each do |type, counts|
        html << "#{InstanceMapping.customer_facing_type(project.platform, type)}: "
        html << " <del> #{counts[:from]} node#{"s" if counts[:from] > 1 || counts[:from] == 0} </del> " if counts[:from]
        html << " #{counts[:to]} node#{"s" if counts[:to] > 1 || counts[:to] == 0}" if counts[:to]
        html << "<br>"
      end
    end
    html << "<br>"
    html
  end

  def status
    "completed"
  end

  def as_json(options={})
    {
      type: "change_request_change_log",
      username: user.username,
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

  def set_updates
    { from: @original_attributes, to: @new_attributes }
  end

  def includes_change
    if !changed_attributes.any?
      errors.add(:log, "must include a change")
    end
  end
end
