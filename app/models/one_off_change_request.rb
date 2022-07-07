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
    status == "pending" && date_time <= Time.current
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

  # TODO: Update as not working correctly when minimum counts with same
  # values as current, for today
  def check_and_update_target_counts(group, type, current_status)
    action = nil
    return action if !counts[group] || !counts[group][type]

    if current_status == "on"
      update_comparison_count(group, type, 1)
    else
      # set to 0 if off and first of this group & type
      update_comparison_count(group, type, 0)
    end

    comparison = @comparison_counts[group][type]
    target_count = counts[group][type]
    
    if comparison < target_count
      if current_status == "off"
        update_comparison_count(group, type, 1)
        action = "on"
      end
    elsif comparison > target_count && counts_criteria == "exact"
      if current_status == "on"
        update_comparison_count(group, type, -1)
        action = "off"
      end
    end
    action 
  end

  def update_comparison_count(group, type, amount)
    if @comparison_counts[group]
      if @comparison_counts[group][type]
        @comparison_counts[group][type] += amount
      else
        @comparison_counts[group][type] = amount
      end
    else
      @comparison_counts[group] = {type => amount}
    end
    @comparison_counts[group][type] = 0 if @comparison_counts[group][type] < 0
  end

  def reset_comparison_counts
    @comparison_counts = {}
  end

  def start
    if temporary?
      ChangeRequest.find(parent_id).start
    else
      super
    end
  end

  def link
    "/events/#{actual_or_parent_id}/edit?project=#{project.name}"
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
