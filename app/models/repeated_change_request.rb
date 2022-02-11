class RepeatedChangeRequest < ChangeRequest
  include Weekdays
  validates :weekdays, :end_date, presence: true
  validate :seven_days
  validate :at_least_one_day
  validate :end_date_not_before_start

  def parsed_end_date_time
    Time.parse("#{end_date.to_s} #{time}")
  end

  def future_dates
    if !@future_dates
      start = [date, Date.today].max
      start += 1.day if start == Date.today && actioned_at && Date.parse(actioned_at) == Date.today
      @future_dates = (start..end_date).to_a.map { |date| date.to_s if date == date || named_weekdays.include?(date.strftime("%a")) }.compact
    end
    @future_dates
  end

  def action_on_date?(date)
    future_dates.include?(date)
  end

  def individual_request_on_date(date)
    return nil if !future_dates.include?(date)

    request = OneOffChangeRequest.new(child_request_attributes(date))
    request.set_as_temporary_child(self.id)
    request
  end

  # for calculations, create standard scheduled request objects for use in calculations, etc.
  def as_future_individual_requests
    return [] if status == "cancelled" || status == "complete"

    future_dates.map { |date| individual_request_on_date(date) }
  end

  # only completed once all involved requests complete
  def complete
    if future_dates.empty?
      super
    end
  end

  def start
    actioned_at = Time.now
    super
  end

  def editable?
    status == "started" || super
  end

  def additional_field_details(slack=false)
    details = ""
    if slack
      #details = "*Override monitor for*: #{monitor_override} hours\n" if monitor_override
      details << "\n*Repeat until*: #{end_date}\n"
      details << "*On days*: #{formatted_days}\n"
    else
      #details = "<strong>Override monitor for</strong>: #{monitor_override} hours<br>" if monitor_override
      details << "<br><strong>Repeat until</strong>: #{end_date}<br>"
      details << "<strong>On days</strong>: #{formatted_days}<br>"
    end
    details
  end

  private

  def end_date_not_before_start
    errors.add(:end_date, "must be after start date") if parsed_end_date_time < date_time
  end

  def child_request_attributes(date)
    details = self.attributes.except("id", "weekdays", "end_date", "repeat", "status", "type")
    details[:type] = "OneOffScheduledRequest"
    details[:status] = "pending"
    details[:date] = date.to_s
    details    
  end
  
  def time_in_future
    return if !date_changed?
    
    super
  end
end
