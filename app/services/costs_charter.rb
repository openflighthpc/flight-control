class CostsCharter

  def initialize(project)
    @project = project
  end

  # starting with actual costs only
  def cost_breakdown(start_date, end_date)
    results = {}
    latest_cost_log_date = @project.cost_logs.last&.date
    (start_date..end_date).to_a.each do |date|
      if latest_cost_log_date && date <= latest_cost_log_date
        results[date.to_s] = {data_out: 0.0, core: 0.0, core_storage: 0.0, 
                              total: 0.0, other: 0.0, budget: 0.0}
        @project.current_compute_groups.each do |group|
          results[date.to_s][group.to_sym] = 0.0
          results[date.to_s]["#{group}_storage".to_sym] = 0.0
        end
      end
    end

    cost_logs = @project.cost_logs.where("date <= ? AND date >= ?", end_date, start_date)
    cost_logs.each do |log|
      results[log.date.to_s][log.scope.to_sym] = log.risk_cost
    end
   
    # budget_changes = continuous_budget? ? cumulative_cycle_budget_changes(start_date) : cycle_budget_changes(start_date)
    # budget = nil
    # total = 0.0
    # previous_costs = latest_previous_costs(start_date)
    # results.keys.each do |k|
    #   break if @parsed_end_date && Date.parse(k) >= @parsed_end_date

    #   budget = budget_changes[k] if budget_changes.has_key?(k)
    #   if @latest_cost_log_date && Date.parse(k) <= @latest_cost_log_date
    #     compute_costs = compute_groups.keys.reduce(0.0) {|sum, group| sum + results[k][group.to_sym]}
    #     results[k][:other] = results[k][:total] - (compute_costs + results[k][:data_out] + results[k][:core] + results[k][:storage])
    #     results[k][:other] = 0.0 if results[k][:other] < 0 # due to rounding if very small numbers
    #     total += results[k][:total]
    #     results[k][:budget] = budget - total
    #     previous_costs = results[k]
    #   elsif Date.parse(k) >= @parsed_start_date
    #     compute = 0.0
    #     compute_groups.keys.each do |group|
    #       results[k]["forecast_#{group}".to_sym] = forecast_compute_cost(Date.parse(k), group.to_sym, change_request, scheduled_request)
    #       compute += results[k]["forecast_#{group}".to_sym]
    #     end
    #     results[k][:forecast_compute] = compute
    #     results[k][:forecast_data_out] = previous_costs[:data_out]
    #     results[k][:forecast_core] = previous_costs[:core]
    #     results[k][:forecast_storage] = previous_costs[:storage]
    #     results[k][:forecast_total] = previous_costs[:total] - previous_costs[:compute] + compute
    #     results[k][:forecast_other] = results[k][:forecast_total] - (compute + previous_costs[:data_out] + previous_costs[:core] + previous_costs[:storage])
    #     results[k][:forecast_other] = 0 if results[k][:forecast_other] < 0 # due to rounding if very small numbers
    #     total += results[k][:forecast_total]
    #     results[k][:forecast_budget] = budget - total
    #   end
    # end
    results
  end

  # To Do
  def budget_changes(start_date, end_date)
    # need to consider budget policies (and balances), end date
    # and when a cycle end/starts (unless continuous).
  end

  def active_billing_cycles
    cycle = start_of_billing_interval(@project.start_date)
    return [cycle] if cycle > start_of_billing_interval(Date.today)

    active_cycles = []
    end_cycle = end_of_billing_interval(Date.today) + 1.day

    if @project.end_date && (@project.end_date - 1.day) < end_cycle
      end_cycle = start_of_billing_interval(@project.end_date - 1.day)
    end

    while (cycle <= end_cycle)
      active_cycles << cycle
      cycle = end_of_billing_interval(cycle) + 1.day
    end
    active_cycles
  end

  def start_of_billing_interval(date)
    if @project.cycle_interval == "monthly"
      date =  date - 1.month if date.day < billing_start_day_of_month
      start = date.beginning_of_month
      [start + (billing_start_day_of_month - 1).days, date.end_of_month].min # in case short month and billing day at end
    elsif @project.cycle_interval == "weekly"
      date =  date - 1.week if date.wday < billing_start_day_of_week
      start = date.beginning_of_week
      start + (billing_start_day_of_week - 1).days
    elsif cycle_interval == "custom"
      last = @project.start_date
      current = @project.start_date
      while(current <= date)
        last = current
        current += @project.cycle_days.days
      end
      last
    end
  end

  def end_of_billing_interval(date)
    if  @project.cycle_interval == "monthly"
      start_of_billing_interval(date + 1.month + 4.days) - 1.day
    elsif  @project.cycle_interval == "weekly"
      start_of_billing_interval(date + 1.week) - 1.day
    else
      start_of_billing_interval(date + @project.cycle_days.days) - 1.day
    end
  end

  def billing_start_day_of_month
    1
  end

  def billing_start_day_of_week
    start_date.wday
  end
end
