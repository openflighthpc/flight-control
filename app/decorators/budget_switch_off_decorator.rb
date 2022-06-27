# for displaying budget switch offs in future events tables
class BudgetSwitchOffDecorator
  attr_reader :date, :time, :updated_at, :switch_offs

  def initialize(date, switch_offs, platform)
    @date = date
    @time = Project::BUDGET_SWITCH_OFF_TIME
    @switch_offs = switch_offs
    @updated_at = Time.now
    @platform = platform
  end

  def date_time
    Time.parse("#{@date.to_s} #{@time}")
  end

  # we know there can only be one set of switch offs per day
  def front_end_id
    "budget-off-#{date}"
  end

  # Includes counts for any of the provided groups
  def included_in_groups?(groups)
    groups.detect { |group| includes_group?(group) }
  end

  def includes_group?(group)
    switch_offs[group] && !switch_offs[group].blank?
  end

  def descriptive_counts
    results = {}
    switch_offs.each do |group, instance_types|
      customer_facing_types = instance_types.map do |k,v|
        [InstanceMapping.customer_facing_type(@platform, k),v]
      end.to_h
      results[group] = customer_facing_types
    end
    results
  end

  def description_partial
    'over_budget_switch_off_details'
  end

  def counts_criteria
    "-"
  end

  def description
    'Automated budget switch off'
  end

  def monitor_override_hours
    nil
  end

  def editable?
    false
  end

  def cancellable?
    false
  end

  def as_json(options={})
    {
      type: "budget_switch_off",
      username: "Automated",
      date: date,
      time: time,
      counts_criteria: counts_criteria,
      descriptive_counts: descriptive_counts,
      frontend_id: front_end_id,
      updated_at: updated_at,
      editable: editable?,
      cancellable: cancellable?
    }
  end

  def to_json(*options)
    as_json(*options).to_json(*options)
  end
end
