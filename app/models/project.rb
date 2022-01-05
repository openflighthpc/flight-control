class Project < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :slack_channel, :start_date, :filter_level, :security_id, :security_key,
            :type, :archived, presence: true
  validate :start_date_valid, on: [:update, :create]
  validate :end_date_valid, on: [:update, :create], if: -> { end_date != nil }
  validate :end_date_after_start, on: [:update, :create], if: -> { end_date != nil }
  validates :platform,
    presence: true,
    inclusion: {
      in: %w(aws azure),
      message: "%{value} is not a valid platform"
    }
  scope :active, -> { where(archived: false) }

  private

  def start_date_valid
    errors.add(:start_date, "Must be a valid date") if !date_valid?(self.start_date)
  end

  def end_date_valid
    errors.add(:end_date, "Must be a valid date") if !date_valid?(self.end_date)
  end

  def end_date_after_start
    starting = date_valid?(self.start_date)
    ending = date_valid?(self.end_date)
    if starting && ending && ending <= starting    
      errors.add(:end_date, "Must be after start date")
    end
  end

  def date_valid?(date)
    begin
      Date.parse(date)
    rescue ArgumentError, TypeError
      false
    end
  end
end
