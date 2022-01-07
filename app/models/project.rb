require_relative 'instance_log'

class Project < ApplicationRecord
  has_many :instance_logs
  before_save :set_type, if: Proc.new { |p| !p.persisted? || p.platform_changed? }
  validates :name, presence: true, uniqueness: true
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

  def record_instance_logs(rerun=false)
    # can't record instance logs if resource group deleted
    if archived
      return "Logs not recorded, project is archived"
    end

    if instance_logs.where(date: Date.today).any?
      if rerun
        print "Updating existing logs. "
      else
        return "Logs already recorded for today. Run task again with 'rerun' as true to overwrite existing logs."
      end
    else
      print "Writing new logs for today. "
    end
    instance_recorder&.record_logs(rerun)
  end

  def instance_recorder
    # platform specific, so none in this superclass
  end

  private

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
end
