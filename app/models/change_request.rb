class ChangeRequest < ApplicationRecord
  belongs_to :project
  has_many :action_logs
  validates :project_id, :counts, :date, :counts_criteria, :time, :status, :type, presence: true
  validate :time_in_future, if: Proc.new { |s| !s.persisted? || s.time_or_date_changed? }
  validate :only_one_at_time, if: Proc.new { |s| !s.persisted? || s.time_or_date_changed? }
  validate :includes_counts, if: Proc.new { |s| !s.persisted? || s.counts_changed? }
  validate :not_over_budget, if: Proc.new { |s| !s.persisted? || s.counts_changed? || s.time_or_date_changed? }

  def nodes=(nodes)
    @nodes = nodes
    update_counts
  end

  after_initialize do |change_request|
    change_request.counts ||= formatted_counts
    change_request.status ||= "pending"
  end

  def update_counts
    counts = formatted_counts
  end

  def date_time
    Time.parse("#{date.to_s} #{time}")
  end

  def actual_or_parent_id
    self.id
  end

  def customer_facing(type)
    InstanceMapping.customer_facing_type(project.platform, type)
  end

  def formatted_changes(with_opening=true)
    message = ""
    opening ="#{"Someone"} requested the following scheduled #{counts_criteria} counts for *#{self.project.name}*:\n"
    counts.each do |group, details|
      message << "*#{group}*\n"
      details.each { |instance, count| message << "#{instance}: #{count} node#{"s" if count > 1 || count == 0}\n" }
    end
    message << "\n*Scheduled time*: #{date_time}\n"
    message << additional_field_details(true)
    message = opening << message if with_opening
    message
  end

  def formatted_actions
    message = ""
    changed = false
    actual_counts = project.actual_with_pending_counts
    counts.each do |group, nodes|
      group_message = "*#{group}*\n"
      group_changed = false
      nodes.each do |instance, count|
        actual_count = actual_counts[group][instance]
        diff = count - actual_count
        if diff > 0
          group_changed = true
          changed = true
          group_message << "#{instance}: turn on #{diff} node#{"s" if diff > 1}\n"
        elsif diff < 0 && counts_criteria == "exact"
          group_changed = true
          changed = true
          group_message << "#{instance}: turn off #{diff.abs} node#{"s" if diff.abs > 1}\n"
        end
      end
      message << group_message if group_changed
    end
    if changed
      message = "Changes submitted to for automated actioning as part of a scheduled request for *#{project.name}*\n\n" << message
    else
      message = "No changes required to meet #{counts_criteria} counts in the scheduled request at #{date_time} for *#{project.name}*\n"
    end
    message
  end

  def card_description
    html = "Requested the following:<br><br>"
    html << "<div class='change-details'>"
    counts.each do |group, details|
      html << "<strong>#{group}</strong><br>"
      details.each { |instance, count| html << "#{customer_facing(instance)}: #{count} node#{"s" if count > 1 || count == 0}<br>" }
    end
    html << "<br><strong>Start time</strong>: #{date_time}<br>"
    html << additional_field_details
    html << "</div>"
    html
  end

  def additional_field_details(slack=false)
    ""
  end

  def formatted_timestamp
    created_at.strftime('%-I:%M%P %F')
  end

  def formatted_days
    nil
  end

  def partial
    :change_request_card
  end

  def includes_instance_type?(group, instance_type)
    counts[group][instance_type]
  end

  # Includes counts for any of the provided groups
  def included_in_groups?(groups)
    groups.detect { |group| counts[group] }
  end

  def instances_to_change_with_pending
    actions = {on: [], off: []}
    project_logs = project.latest_instance_logs
    counts.each do |group, nodes|
      nodes.each do |instance, count|
        instance_logs = project_logs.where(instance_type: instance, compute_group: group)
        on_instances = instance_logs.select { |instance| instance.pending_on? }
        diff = count - on_instances.count
        if diff > 0
          off_instances = instance_logs.select { |instance| !instance.pending_on? }
          instances = off_instances.first(diff.abs)
          actions[:on] = actions[:on].concat(instances)
        elsif diff < 0 && counts_criteria == "exact"
          instances = on_instances.first(diff.abs)
          actions[:off] = actions[:off].concat(instances)
        end
      end
    end
    actions
  end

  def check_and_update_status
    if !@checked
      @checked = true
      return if status != "started"

      action_logs.reorder("actioned_at DESC").each do |log|
        log.check_and_update_status
        return if log.status == "pending"
      end
      complete
    end
  end

  def start
    self.status = "started"
    save!
  end

  def complete
    self.status = "completed"
    save!
  end

  def cancel
    if cancellable?
      self.status = "cancel"
      save!
    end
  end

  # When we have change logs, we will want to show the original content,
  # but the current status
  def as_json(*options)
    request = self
    {
      type: "scheduled_request",
      username: "Someone",
      date: request.date,
      time: request.time,
      timestamp: request.created_at,
      formatted_timestamp: request.formatted_timestamp,
      details: request.card_description,
      descriptive_counts: descriptive_counts,
      status: status,
      editable: editable?,
      counts_criteria: counts_criteria.capitalize,
      frontend_id: front_end_id,
      #link: self.link,
      updated_at: updated_at.to_s
    }
  end

  def to_json(*options)
    as_json(*options).to_json(*options)
  end

  def front_end_id
    "#{id}-#{date}"
  end

  def time_or_date_changed?
    time_changed? || date_changed?
  end

  def editable?
    status == "pending" && date_time >= (Time.now + 5.minutes)
  end

  def cancellable?
    status == "pending"
  end

  # def link
  #   "/change_requests/#{self.id}?project=#{self.project.name}"
  # end

  def switch_all_on?(group_name)
    project_instances = project.latest_instances[group_name]
    return false if counts[group_name].length != project_instances.length

    request_counts = counts[group_name]
    missing = project_instances.detect { |instance| request_counts[instance.instance_type] != instance.total_count }
    !missing
  end

  def descriptive_counts
    results = {}
    counts.each do |group, instance_types|
      if switch_all_on?(group)
        results[group] = "All on"
      else
        customer_facing_types = instance_types.map do |k,v|
          [InstanceMapping.customer_facing_type(project.platform, k),v]
        end.to_h
        results[group] = customer_facing_types
      end
    end
    results
  end

  private

  def formatted_counts
    instances = {}
    @nodes.each do |id, count|
      if count != ""
        group = id.split("-")[0]
        type = id.split("-")[1]
        type.gsub!("_", ".") if !type.start_with?("Standard")
        if instances.has_key?(group)
          instances[group][type] = count.to_i
        else
          instances[group] = {type => count.to_i}
        end
      end
    end
    instances
  end

  def includes_counts
    errors.add(:counts, "must include at least one node count") if counts.empty?
  end

  def time_in_future
    errors.add(:time, "#{date_time }must be at least 5 mins in the future") if (date_time - 5.minutes) < Time.now
  end

  def only_one_at_time
    dates = future_dates
    self.project.change_requests.where(time: self.time).where.not(id: self.id).where.not(status: "cancelled").each do |request|
      if (request.future_dates & dates).any?
        errors.add(:time, "must not be the same as an existing request with actions on the same date")
        return  
      end  
    end
  end

  def not_over_budget
     errors.add(:counts, "must not result in going over budget") if project.change_request_goes_over_budget?(self)
  end
end
