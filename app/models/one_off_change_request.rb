class OneOffChangeRequest < ChangeRequest
  validates :weekdays, :end_date, presence: false
  attr_reader :comparison_counts

  after_initialize do |request|
    @comparison_counts = {}
  end

  # if created as a temporary object by a repeated request
  def set_as_temporary_child(parent_id)
    @temporary = true
    @parent_id = parent_id
  end

  def temporary?
    @temporary
  end

  def parent_id
    @parent_id
  end

  def actual_or_parent_id
    @parent_id || self.id
  end

  def front_end_id
    "#{actual_or_parent_id}-#{date}"
  end

  def due?
    status == "pending" && date_time <= Time.now
  end

  def action_on_date?(date)
    self.date == Date.parse(date)
  end

  # three methods below are so can be interchangeable with repeated request
  def future_dates
    status == "pending" ? [date] : []
  end

  def as_future_individual_requests
    status == "pending" ? [self] : []
  end

  def individual_request_on_date(date)
    action_on_date?(date) ? self : nil
  end

  def required_switch_on(group, type, current_status)
    action = false
    return action if !counts[group] || !counts[group][type]

    target_count = counts[group][type]
    comparison = @comparison_counts[group]
    comparison = comparison ? comparison[type] : 0
    comparison ||= 0
    if comparison < target_count
      action = true if current_status == "off"
      increment_comparison_count(group, type)
    end
    action
  end

  def increment_comparison_count(group, type)
    if @comparison_counts[group]
      if @comparison_counts[group][type]
        @comparison_counts[group][type] += 1
      else
        @comparison_counts[group][type] = 1
      end
    else
      @comparison_counts[group] = {type => 1}
    end
  end

  def start
    if temporary?
      ChangeRequest.find(parent_id).start
    else
      super
    end
  end

  def complete
    return if temporary?

    super
  end

  def check_and_update_status
    return if temporary?

    super
  end
end
