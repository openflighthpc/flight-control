# for displaying budget switch offs in future events tables
class BudgetSwitchOffDecorator
  SWITCH_OFF_TIME = "23:30"

  attr_reader :date, :time, :updated_at, :switch_offs

  def initialize(date, switch_offs)
    @date = date
    @time = SWITCH_OFF_TIME
    @switch_offs = switch_offs
    @updated_at = Time.now
  end

  def date_time
    Time.parse("#{self.date} #{self.time}")
  end

  # we know there can only be one set of switch offs per day
  def front_end_id
    "budget-off-#{date}"
  end

  def descriptive_counts
    results = {}
    switch_offs.each do |group, instance_types|
      customer_facing_types = instance_types.map do |k,v|
        [InstanceMapping.customer_facing_name(k),v]
      end.to_h
      results[group] = customer_facing_types
    end
    results
  end

  def as_json(options={})
    {
      type: "budget_switch_off",
      username: "Automated",
      date: date,
      time: time,
      descriptive_counts: descriptive_counts,
      frontend_id: front_end_id,
      updated_at: updated_at
    }
  end

  def to_json(*options)
    as_json(*options).to_json(*options)
  end
end
