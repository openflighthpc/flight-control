require_relative 'instance_log'
require_relative 'cost_log'
require_relative "../services/project_config_creator"
require 'httparty'

class Project < ApplicationRecord
  DEFAULT_COSTS_DATE = Date.today - 3
  SCOPES = %w[total data_out core core_storage]
  has_many :instance_logs
  has_many :cost_logs
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
  scope :active, -> { where(archived: false) }

  def self.slack_token
    @@slack_token ||= Rails.application.config.slack_token
  end

  def latest_instance_logs
    instance_logs.where(date: instance_logs.maximum(:date))
  end

  def current_compute_groups
    latest_instance_logs.pluck(Arel.sql("DISTINCT compute_group")).compact
  end

  def compute_groups_on_date(date)
    logs = instance_logs.where(date: date)
    # If no logs on that, get most recent earlier logs
    if !logs.any?
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

  def record_instance_logs(rerun=false, verbose=false)
    # can't record instance logs if resource group deleted
    if archived
      return "Logs not recorded, project is archived"
    end
    
    outcome = ""
    if instance_logs.where(date: Date.today).any?
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

    if cost_logs.where(date: date).any?
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
    any_logs = date_logs.any?
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
      "*Total Compute Units (Flat):* #{total_log.compute_cost}",
      "*Total Compute Units (Risk):* #{total_log.risk_cost}"
    ].compact.join("\n") + "\n"

    send_slack_message(msg) if slack

    if text
      msg << "_" * 50
      msg << "\n"
      puts msg.gsub(":moneybag:", "").gsub("*", "").gsub("\t", "")
    end
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
end
