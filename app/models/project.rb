require_relative 'hub_balance'
require_relative 'budget_policy'
require_relative 'instance_log'
require_relative 'cost_log'
require_relative 'action_log'
require_relative '../services/project_config_creator'
require_relative '../services/costs_plotter'
require_relative '../services/instance_tracker'
require_relative '../services/funds_manager'
require_relative '../decorators/budget_switch_off_decorator'
require 'httparty'

class Project < ApplicationRecord
  BUDGET_SWITCH_OFF_TIME = "23:30"
  DEFAULT_COSTS_DATE = Date.current - 3
  SCOPES = %w[total data_out core core_storage]
  has_many :instance_logs
  has_many :cost_logs
  has_many :action_logs
  has_many :config_logs
  has_many :change_requests
  has_many :change_request_audit_logs
  has_many :one_off_change_requests
  has_many :repeated_change_requests
  has_many :hub_balances
  has_many :budget_policies
  has_many :budgets
  has_many :funds_transfer_requests
  has_many :user_roles

  before_save :set_type, if: Proc.new { |p| !p.persisted? || p.platform_changed? }
  validates :name, presence: true, uniqueness: true
  validates :flight_hub_id, presence: true, uniqueness: true
  validates :name, :format => { with: /\A[a-zA-Z]+[0-9a-zA-Z_-]*[0-9a-zA-Z]+\z/,
            message: 'Must start with letters and only include letters, numbers, dashes or underscores.' }
  validates :slack_channel, :start_date, :filter_level, :security_id, :security_key,
            :type, presence: true
  validate :end_date_after_start, on: [:update, :create], if: -> { end_date != nil }
  validates :platform,
    presence: true,
    inclusion: {
      in: %w(aws azure),
      message: "%{value} is not a valid platform"
    }
  after_save :update_end_balance
  scope :active, -> { where("archived_date IS NULL OR archived_date > ?", Date.current) }
  scope :visualiser, -> { where(visualiser: true) }

  def self.slack_token
    @@slack_token ||= Rails.application.config.slack_token
  end

  def archived?
    # use !! so returns false instead nil, which confuses table print
    !!(archived_date && archived_date <= Date.current)
  end

  def latest_instance_logs
    instance_logs.where(date: instance_logs.maximum(:date))
  end

  def pending_actions?
    if @pending_actions == nil
      @pending_actions = pending_action_logs.exists?
    end
    @pending_actions
  end

  def pending?
    if @pending == nil
      @pending = (pending_actions? || pending_one_off_and_repeat_requests.any?)
    end
    @pending
  end

  # Run this only when new instance logs are created (as we know
  # statuses can't have changed unless instance statuses have changed)
  def check_and_update_pending_changes
    change_requests.where.not(status: "complete").where.not(
                              status: "cancelled").reorder(
                              "updated_at DESC").each { |request| request.check_and_update_status }
    action_logs.where(change_request_id: nil, status: "pending").each { |action| action.check_and_update_status }
  end

  def pending_one_off_change_requests
    one_off_change_requests.where(status: "pending")
  end

  # For repeat requests, they are pending (but don't necessarily have a 
  # status of pending) until all their actions on every date are complete
  def pending_repeated_requests
    repeated_change_requests.where.not(status: "complete").where.not(status: "cancelled")
  end

  def pending_repeated_request_children
    if !@repeated_request_children
      @repeated_request_children = pending_repeated_requests.map { |repeated| repeated.as_future_individual_requests }.flatten
    end
    @repeated_request_children
  end

  def pending_one_off_and_repeat_requests
    if !@combined_requests
      @combined_requests = pending_one_off_change_requests.to_a.concat(pending_repeated_request_children).compact
      @combined_requests = @combined_requests.sort_by { |request| [request.date, request.time] }
    end
    @combined_requests
  end

  def pending_one_off_and_repeat_requests_on(date, groups=nil)
    pending = pending_one_off_change_requests.where(date: date)
    pending = pending.to_a.select { |request| request.included_in_groups?(groups) } if groups
    repeated = pending_repeated_requests.select do |repeat|
      repeat.action_on_date?(date) && (!groups ||
      repeat.included_in_groups?(groups))
    end
    repeated_children = repeated.map { |repeat| repeat.individual_request_on_date(date) }
    pending.to_a.concat(repeated_children).compact
  end

  def request_dates_and_times(exclude_request=nil)
    results = {}
    requests = pending_one_off_and_repeat_requests
    requests.reject! { |request| request.actual_or_parent_id == exclude_request.actual_or_parent_id } if exclude_request
    requests.pluck(:date, :time).each do |timing|
      date = timing[0]
      time = timing[1]
      if results[date]
        results[date][time] = true
      else
        results[date] = {time => true }
      end
    end
    results
  end

  def events(groups=nil, recalculate_budget_off=true)
    events = pending_one_off_and_repeat_requests.concat(decorated_switch_offs(recalculate_budget_off))
    events = events.select { |event| event.included_in_groups?(groups) } if groups
    events
  end

  def events_on(date, groups=nil)
    requests = pending_one_off_and_repeat_requests_on(date, groups)
    switch_offs = decorated_switch_offs.select { |off| off.date == date && (!groups || off.included_in_groups?(groups)) }
    requests.concat(switch_offs)
  end

  def events_by_date(chosen_events=events)
    chosen_events.sort_by {|e| [e.date, e.time]}.group_by {|e| e.date}
  end

  # within next 5 mins
  def upcoming_events(groups=nil)
    today_events = events_on(Date.current, groups)
    five_mins_from_now = Time.current + 5.minutes
    today_events.select { |event| event.date_time <= five_mins_from_now }
  end

  def upcoming_events_by_date(groups=nil)
    events_by_date(upcoming_events(groups))
  end

  # after next 5 mins
  def future_events(groups=nil, recalculate_budget_off=true)
    five_mins_from_now = Time.current + 5.minutes
    future = events(groups, recalculate_budget_off)
    future.select { |event| event.date_time > five_mins_from_now }
  end

  def future_events_by_date(groups=nil, recalculate_budget_off=true)
    events_by_date(future_events(groups, recalculate_budget_off))
  end

  def events_by_id(events)
    results = {}
    events.each do |date, events|
      results[date] = {}
      events.each do |event|
        results[date][event.front_end_id] = event
      end
    end
    results
  end

  # For front end use and in cost forecast calculations
  def latest_instances(temp_change_request=nil)
    if !@instances || temp_change_request
      @instances = InstanceTracker.new(self).latest_instances(temp_change_request)
    end
    @instances
  end

  def nodes_up
    InstanceTracker.new(self).nodes_up
  end

  # For resetting after temp
  def reset_latest_instances
    @instances = nil
  end

  def pending_action_logs
    action_logs.where(status: "pending")
  end

  def current_hub_balance
    hub_balances.where("date <= ?", Date.current).last
  end

  def current_budget_policy
    @budget_policy ||= budget_policies.where("effective_at <= ?", Date.current).last
  end

  def continuous_budget?
    current_budget_policy.spend_profile == "continuous"
  end

  def fixed_budget?
    current_budget_policy.spend_profile == "fixed" 
  end

  def cycle_days
    current_budget_policy.days
  end

  def cycle_interval
    current_budget_policy.cycle_interval
  end

  def current_compute_groups
    @current_groups ||= latest_instance_logs.pluck(Arel.sql("DISTINCT compute_group")).compact
  end

  def settings
    if !@settings
      @settings = YAML.load(File.read(File.join(Rails.root, 'config', 'projects', "#{name}.yaml")))
    end
    @settings
  end

  def front_end_compute_groups
    settings["compute_groups"]
  end

  def compute_groups_on_date(date)
    logs = instance_logs.where(date: date)
    # If no logs on that, get most recent earlier logs
    if !logs.exists?
      latest_date = instance_logs.where("date < ?", date).maximum(:date)
      if latest_date
        logs = instance_logs.where(date: latest_date)
      else
        return []
      end
    end
    logs.pluck(Arel.sql("DISTINCT compute_group")).compact.compact
  end

  def create_config_file(overwrite=false)
    ProjectConfigCreator.new(self).create_config_file(overwrite)
  end

  def time_of_latest_change
    latest_cost_data = cost_logs.maximum("updated_at") if cost_logs.exists?
    latest_instance_data = instance_logs.maximum("updated_at") if instance_logs.exists?
    latest_action_log = action_logs.maximum("updated_at") if action_logs.exists?
    latest_change_request = change_requests.maximum("updated_at") if change_requests.exists?
    if latest_cost_data || latest_instance_data || latest_action_log || latest_change_request
      latest = [latest_cost_data, latest_instance_data, latest_action_log, latest_change_request].compact.max
    else
      latest = Date.current.to_time
    end
    latest
  end

  # Timestamps are stored in db with more precision than can be easily represented,
  # so a parsed string will not necessarily equal the same time (as we see it) in the db.
  # To get around this we case the Times to ints to remove some of the precision.
  def data_changed?(timestamp)
    time_of_latest_change.to_i > timestamp.to_i
  end

  def record_instance_logs(rerun=false, verbose=false)
    # can't record instance logs if resource group deleted
    if archived?
      return "Logs not recorded, project is archived"
    end
    
    outcome = ""
    if instance_logs.where(date: Date.current).exists?
      if rerun
        outcome << "Updating existing logs. "
      else
        return "Logs already recorded for today. Run task again with 'rerun' as true to overwrite existing logs."
      end
    else
      outcome << "Writing new logs for today. "
    end
    outcome << instance_recorder&.record_logs(rerun)
    check_and_update_pending_changes
    outcome
  end

  def record_cost_logs(date=DEFAULT_COSTS_DATE, rerun=false, text=false, verbose=false)
    check_costs_date(date)

    if cost_logs.where(date: date).exists?
      if rerun
        print "Updating existing logs. " if text
      else
        print "Logs already recorded for today. Run task again with 'rerun' as true to overwrite existing logs." if text
        return false
      end
    else
      print "Writing new logs for today. " if text
    end
    print "Success" if costs_recorder&.record_logs(date, date, rerun, verbose) && text
  end

  def record_cost_logs_for_range(start_date, end_date, rerun=false, text=false, verbose=false)
    puts "Success" if costs_recorder&.record_logs(start_date, end_date, rerun, verbose) && text
  end

  # we want to run all the validations, even if one has already
  # failed, so we can see all that have issues.
  def validate_credentials
    puts "Validating credentials"
    success = true
    success = false if !additional_validations
    success = false if !costs_recorder&.validate_credentials
    success = false if !instance_recorder&.validate_credentials
    success = false if !instance_details_recorder&.validate_credentials
    puts success ? "Credentials valid" : "Validation failed."
    return success
  end

  def record_instance_details
    instance_details_recorder.record
  end

  def instance_recorder
    # platform specific, so none in this superclass
  end

  def costs_recorder
    # platform specific, so none in this superclass
  end

  def instance_details_recorder
    # platform specific, so none in this superclass
  end

  def instance_manager
    # platform specific, so none in this superclass
  end

  def monitor
    # platform specific, so none in this superclass
  end

  def monitor_currently_active?
    monitor_active && (!override_monitor_until ||
    override_monitor_until <= Time.current)
  end

  def monitor_override_active?
    monitor_active && override_monitor_until &&
    override_monitor_until > Time.current
  end

  def costs_plotter
    @costs_plotter ||= CostsPlotter.new(self)
  end

  def funds_manager
    @funds_manager ||= FundsManager.new(self)
  end

  def check_and_switch_off_idle_nodes(slack=false)
    return if !utilisation_threshold

    monitor.check_and_switch_off(slack)
  end

  def daily_report(date=DEFAULT_COSTS_DATE, rerun=false, slack=true, text=true, verbose=false)
    return if !check_costs_date(date)

    date_logs = cost_logs.where(date: date)
    any_logs = date_logs.exists?
    cached = true
    if !any_logs || rerun
      cached = false
      record_cost_logs(date, rerun, false, verbose)
    end
    compute = date_logs.where(compute: true).sum(:cost)
    data_out = date_logs.find_by(scope: "data_out").cost
    total_log = date_logs.find_by(scope: "total")
    total = total_log.cost
    currency = total_log.currency

    date_warning = date > Date.current - 2 ? "\nWarning: costs data takes roughly 48 hours to update, so these figures may be inaccurate\n" : nil
    msg = [
      "#{date_warning if date_warning}",
      "#{"*Cached report*" if cached}",
      ":moneybag: Usage for *#{name}* on #{date.to_s} :moneybag:",
      "*Compute Costs (#{currency}):* #{compute.to_f.ceil(2)}",
      "*Data Out Costs (#{currency}):* #{data_out.to_f.ceil(2)}",
      "*Total Costs (#{currency}):* #{total.to_f.ceil(2)}",
      "*Total Compute Units (Flat):* #{total_log.compute_cost.ceil}",
      "*Total Compute Units (Risk):* #{total_log.risk_cost}"
    ].compact.join("\n") + "\n"

    send_slack_message(msg) if slack

    if text
      msg << "_" * 50
      msg << "\n"
      puts msg.gsub(":moneybag:", "").gsub("*", "").gsub("\t", "")
    end
  end

  def change_request_cumulative_costs(params)
    change = make_change_request(params)
    # This sets the future instance counts based on the
    # if the temp change request were carried out
    latest_instances(change)
    costs, chart_costs = costs_plotter.cumulative_change_request_costs(change)
    results = {costs: chart_costs}
    start_date = costs_plotter.start_of_billing_interval(Date.current)
    end_date = costs_plotter.end_of_billing_interval(start_date)
    results[:balance_end] = costs_plotter.estimated_balance_end_in_cycle(start_date, end_date, costs, change)
    results[:budget_switch_offs] = costs_plotter.front_end_switch_offs_by_date(start_date, end_date, false)
    results
  end

  def change_request_goes_over_budget?(change_request)
    latest_instances(change_request)
    over = costs_plotter.change_request_goes_over_budget?(change_request)
    reset_latest_instances
    over
  end

  # create object, but don't persist
  def make_change_request(params)
    params["project"] = self
    if params["timeframe"] == "now"
      params["date"] = Date.current
      # use 6 minutes as equivalent to rounding up current time
      # to nearest minute
      params["time"] = (Time.current + 6.minutes).strftime("%H:%M")
    end
    params.delete("timeframe")
    change = params["type"].constantize.new(params)
  end

  def create_change_request(params)
    change = make_change_request(params)
    change.project_id = self.id
    success = change.save
    if success
      msg = change.formatted_changes
      off_msg = @costs_plotter.switch_off_schedule_msg(true, false)
      msg << "\n\nTo meet budget, nodes must also be switched off during the billing cycle. Current recommendations:\n\n#{off_msg}" if off_msg
      send_slack_message(msg)
    end
    change
  end

  def update_change_request(request, user, params)
    return request, false if !request.editable?
    
    # user = params.delete("user")
    original_date_time = request.date_time
    original_attributes = request.attributes
    original_attributes["formatted_days"] = request.formatted_days
    request.assign_attributes(params)
    request.nodes = params["nodes"]
    if !request.changed?
      success = false
    else
      # allow change between one off and repeated request
      request = request.becomes(params["type"].constantize)
      success = request.save
      if success
        msg = "Scheduled request at #{original_date_time} for project *#{self.name}* updated by #{user.username}. Now: \n"
        msg << request.formatted_changes(false)
        request.reload
        new_attributes = request.attributes
        new_attributes["formatted_days"] = request.formatted_days
        create_change_request_log(request.id, user.id, original_attributes, new_attributes)
        send_slack_message(msg)
      end
    end
    return request, success
  end

  def create_change_request_log(request_id, user_id, original_attributes, new_attributes)
    log = ChangeRequestAuditLog.create(project_id: self.id, change_request_id: request_id,
                                       user_id: user_id, original_attributes: original_attributes,
                                       new_attributes: new_attributes, date: Date.current)
  end

  def cancel_change_request(request, user)
    original_status = request.status
    success = request.cancel
    if success
      desc = request.description ? " '#{request.description}' " : " "
      msg = "Scheduled request#{desc}at #{request.date_time} for project *#{request.project.name}* cancelled by #{user.username}"
      create_change_request_log(request.id, user.id, {"status" => original_status}, {"status" => request.status})
      send_slack_message(msg)
    end
    success
  end

  def action_scheduled(slack, text)
    any = false
    pending_one_off_and_repeat_requests.each do |request|
      if request.due?
        any = true
        action_change_request(request, slack, text)
      end
    end
    puts "No scheduled requests due for project #{self.name}." if !any && text
  end

  def action_change_request(request, slack=false, text=false)
    if request.monitor_override_hours
      details = {"override_monitor_until" => request.monitor_end_time.to_s}
      submit_config_change(details, request.user, true, request.actual_or_parent_id, slack, text)
    end
    msg = request.formatted_actions
    send_slack_message(msg) if slack
    puts msg if text
    request.start

    instances_to_change = request.instances_to_change_with_pending
    create_action_logs(instances_to_change, "Change request", request)
    grouped_changes = group_instance_changes(instances_to_change)
    update_instance_statuses(grouped_changes)
  end

  def submit_config_change(details, user, automated=false, request_id=nil, slack=true, text=false)
    change = ConfigLog.new(user_id: user.id, project_id: id, automated: automated,
                           change_request_id: request_id, details: details)
    success = change.save
    if success
      # Will need updating when possible to change compute group priorities,
      # as these in a yaml file, not db fields
      change.config_changes.each do |attribute, value|
        self.assign_attributes({attribute => value["to"]})
      end
      self.save
      msg = change.formatted_changes
      send_slack_message(msg) if slack
      puts msg if text
    end
    change
  end

  def budget_switch_off_schedule(slack=false)
    off_msg = costs_plotter.switch_off_schedule_msg(true, false)
    if off_msg
      msg = "Based on latest forecasts, nodes must be switched off to meet this cycle's budget. Current planned switch offs:\n\n"
      msg << off_msg
    else
      msg = "No budget switch offs required based on current forecasts."
    end
    msg = "Project *#{self.name}*\n" << msg
    msg << "\n\n"
    send_slack_message(msg) if slack
    msg
  end

  def perform_budget_switch_offs(slack=true)
    switch_offs = costs_plotter.today_budget_switch_offs
    if switch_offs.any?
      to_switch_off = []
      msg = "To meet budget for project *#{self.name}*, instances submitted to automated scripts for switch off:\n\n"
      switch_offs.each do |compute_group, instance_types|
        msg << "*#{compute_group}*\n"
        change = false
        instance_types.each do |instance_type, number|
          instances = latest_instance_logs.where(instance_type: instance_type, compute_group: compute_group)
          instances.each {|instance| puts instance.pending_on?}
          instances = instances.select { |instance| instance.pending_on? }
          instances = instances.first(number)
          to_switch_off = to_switch_off.concat(instances)
          msg << "#{number} #{instance_type}\n" if instances.any?
          change = true if instances.any?
        end
        msg << "None\n" if !change
      end
      send_slack_message(msg) if slack
      to_switch_off = {off: to_switch_off}
      create_action_logs(to_switch_off, "Switched off to meet budget")
      grouped_changes = group_instance_changes(to_switch_off)
      update_instance_statuses(grouped_changes)
    else
      msg = "No switch offs required today for project #{self.name} to meet budget, based on current forecasts."
      send_slack_message(msg) if slack
    end
    msg
  end

  # Convert them into a format equivalent to a change request,
  # for use in the front end.
  def decorated_switch_offs(recalculate=true)
    results = []
    costs_plotter.switch_offs_by_date(recalculate).each do |date, details|
      results << BudgetSwitchOffDecorator.new(Date.parse(date), details, platform)
    end
    results
  end

  def create_action_logs(instance_actions, reason, request=nil)
    instance_actions.each do |action, instances|
      instances.each do |instance|
        action_log = ActionLog.new(project_id: id, user_id: request&.user_id,
                                   action: action, reason: reason,
                                   instance_id: instance.instance_id,
                                   change_request_id: request&.actual_or_parent_id,
                                   automated: request.blank?)
        action_log.save!
      end
    end    
  end

  def group_instance_changes(instances_to_change)
    actions = {on: {}, off: {}}
    instances_to_change.each do |action, instances|
      instances.each do |instance|
        # Platforms expect instances to be grouped by different criteria
        # for efficient SDK/API queries, and to use id or name
        grouping = instance.send(instance_grouping)
        identifier = instance.send(instance_identifier)
        if actions[action].has_key?(grouping)
          actions[action][grouping] << identifier
        else
          actions[action][grouping] = [identifier]
        end
      end
    end
    actions
  end

  # This is perhaps doing too much, the grouping and action logs could
  # be elsewhere
  def update_instance_statuses(actions)
    actions.each do |action, details|
      next if details.empty?
      # for aws grouping is region, for azure is resource group
      details.each do |grouping, instances|
        instance_manager.update_instance_statuses(action, grouping, instances)
      end
    end
  end

  def actual_with_pending_counts
    InstanceTracker.new(self).actual_with_pending_counts
  end

  def current_events_data(groups=nil)
    {
      states: InstanceTracker.new(self).actual_counts(groups, true),
      in_progress: pending_action_logs_by_id(groups),
      upcoming: events_by_id(upcoming_events_by_date(groups)),
      future: events_by_id(future_events_by_date(groups))
    }
  end

  def pending_action_logs_by_id(groups=nil)
    results = {}
    pending_action_logs.each do |log|
      results[log.id] = log if !groups || groups.include?(log.compute_group)
    end
    results
  end

  def send_slack_message(msg)
    begin
      HTTParty.post("https://slack.com/api/chat.postMessage",
                  headers: {"Authorization": "Bearer #{Project.slack_token}"},
                  body: {"text": msg, "channel": slack_channel, "as_user": true})
    rescue
      # Don't break actions if can't send a message
    end
  end

  def all_associated_users
    user_roles.map(&:user).concat(User.where(admin: true)).compact.uniq
  end

  def self.deep_copy_hash(hash)
    Marshal.load(Marshal.dump(hash))
  end

  private

  def additional_validations
    true
  end

  def set_type
    type = "#{platform.capitalize}Project"
  end

  def start_date_valid
    #errors.add(:start_date, "Must be a valid date") if !date_valid?(start_date)
  end

  def end_date_valid
    errors.add(:end_date, "Must be a valid date") if !date_valid?(end_date)
  end

  def end_date_after_start
    if start_date && end_date && end_date <= start_date    
      errors.add(:end_date, "Must be after start date")
    end
  end

  def check_costs_date(date)
    if date < start_date
      puts "#{name}: given date is before the project start date for"
      return false
    elsif date > Date.current
      puts "#{name}: Given date is in the future"
      return false
    end
    return true
  end

  def update_end_budget
    FundsManager.new(self).update_end_budget
  end
end
