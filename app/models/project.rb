require_relative 'balance'
require_relative 'budget_policy'
require_relative 'instance_log'
require_relative 'cost_log'
require_relative 'action_log'
require_relative '../services/project_config_creator'
require_relative '../services/costs_plotter'
require_relative '../services/instance_tracker'
require 'httparty'

class Project < ApplicationRecord
  DEFAULT_COSTS_DATE = Date.today - 3
  SCOPES = %w[total data_out core core_storage]
  has_many :instance_logs
  has_many :cost_logs
  has_many :action_logs
  has_many :change_requests
  has_many :one_off_change_requests
  has_many :repeated_change_requests
  has_many :balances
  has_many :budget_policies
  before_save :set_type, if: Proc.new { |p| !p.persisted? || p.platform_changed? }
  validates :name, presence: true, uniqueness: true
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
  scope :active, -> { where("archived_date IS NULL OR archived_date > ?", Date.today) }
  scope :visualiser, -> { where(visualiser: true) }

  def self.slack_token
    @@slack_token ||= Rails.application.config.slack_token
  end

  def archived?
    # use !! so returns false instead nil, which confuses table print
    !!(archived_date && archived_date <= Date.today)
  end

  def latest_instance_logs
    instance_logs.where(date: instance_logs.maximum(:date))
  end

  def pending?
    @pending ||= (pending_action_logs.exists? || pending_one_off_and_repeat_requests.any?)
  end

  # need to add some logic when instance logs are recorded
  # to check if these requests (and action logs) are now complete
  def pending_one_off_change_requests
    one_off_change_requests.where(status: "pending")
  end

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
    combined = pending_one_off_change_requests.to_a.concat(pending_repeated_request_children).compact
    combined.sort_by { |request| [request.date, request.time] }
  end

  # For front end use and in cost forecast calculations
  def latest_instances(temp_change_request=nil)
    if !@instances || temp_change_request
      @instances = InstanceTracker.new(self).latest_instances(temp_change_request)
    end
    @instances
  end

  # For resetting after temp
  def reset_latest_instances
    @instances = nil
  end

  def pending_action_logs
    action_logs.where(status: "pending")
  end

  def current_balance
    balances.where("effective_at <= ?", Date.today).last
  end

  def current_budget_policy
    @budget_policy ||= budget_policies.where("effective_at <= ?", Date.today).last
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
    if latest_cost_data || latest_instance_data || latest_action_log
      latest = [latest_cost_data, latest_instance_data, latest_action_log].compact.max
    else
      latest = Date.today.to_time
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
    if instance_logs.where(date: Date.today).exists?
      if rerun
        outcome << "Updating existing logs. "
      else
        return "Logs already recorded for today. Run task again with 'rerun' as true to overwrite existing logs."
      end
    else
      outcome << "Writing new logs for today. "
    end
    outcome << instance_recorder&.record_logs(rerun)
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

    date_warning = date > Date.today - 2 ? "\nWarning: costs data takes roughly 48 hours to update, so these figures may be inaccurate\n" : nil
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

  def create_change_request(params)
    if params["timeframe"] == "now"
      params["date"] = Date.today
      # use 6 minutes as equivalent to rounding up current time
      # to nearest minute
      params["time"] = (Time.now + 6.minutes).strftime("%H:%M")
    end
    params.delete("timeframe")
    if params["weekdays"] && params["weekdays"] != ""
      change = RepeatedChangeRequest.new(params)
    else
      change = OneOffChangeRequest.new(params)
    end
    change.project_id = self.id
    success = change.save
    msg = change.formatted_changes
    send_slack_message(msg) if success
    change
  end

  def send_slack_message(msg)
    HTTParty.post("https://slack.com/api/chat.postMessage",
                  headers: {"Authorization": "Bearer #{Project.slack_token}"},
                  body: {"text": msg, "channel": slack_channel, "as_user": true})
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
    elsif date > Date.today
      puts "#{name}: Given date is in the future"
      return false
    end
    return true
  end

  # If an end date, ensure we have a corresponding balance
  # with an amount of 0.
  def update_end_balance
    end_balance = balances.where(amount: 0).last
    return if !end_date && !end_balance

    if !end_date && end_balance
      end_balance.delete
    else
      if !end_balance
        Balance.create(project: self, amount: 0, effective_at: end_date)
      elsif end_balance && end_balance.effective_at != end_date
        end_balance.effective_at = end_date
        end_balance.save!
      end
    end
  end
end
