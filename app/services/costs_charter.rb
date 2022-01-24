class CostsCharter

  def initialize(project)
    @project = project
  end

  # starting with actual costs only
  def cost_breakdown(start_date, end_date)
    results = {}
    latest_cost_log_date = @project.cost_logs.last&.date
    compute_groups = @project.current_compute_groups
    # start one day earlier, so we can use previous costs
    # for forecasts, if needed
    ((start_date - 1.day)..end_date).to_a.each do |date|
      if latest_cost_log_date && date <= latest_cost_log_date
        results[date.to_s] = { data_out: 0.0, core: 0.0, core_storage: 0.0, 
                              total: 0.0, other: 0.0, budget: 0.0,
                              compute: 0.0 }
        compute_groups.each do |group|
          results[date.to_s][group.to_sym] = 0.0
          results[date.to_s]["#{group}_storage".to_sym] = 0.0
        end
      end
    end

    cost_logs = @project.cost_logs.where("date <= ? AND date >= ?", end_date, start_date)
    cost_logs.each do |log|
      cost = log.risk_cost
      results[log.date.to_s][log.scope.to_sym] = cost
      if log.compute
        results[log.date.to_s][:compute] += cost
      end
    end
   
    budget_changes = budget_changes(start_date, end_date)
    budget = nil
    total = 0.0
    previous_costs = results.delete((start_date - 1.day).to_s)
    results.keys.each do |k|
      break if @project.end_date && Date.parse(k) >= @project.end_date

      if budget_changes.has_key?(k)
        budget = budget_changes[k]
        total = 0.0
      end
      if latest_cost_log_date && Date.parse(k) <= latest_cost_log_date
        results[k][:other] = results[k][:total] - (results[k][:compute] + results[k][:data_out] + results[k][:core] + results[k][:core_storage])
        results[k][:other] = 0.0 if results[k][:other] < 0 # due to rounding if very small numbers
        total += results[k][:total]
        results[k][:budget] = budget - total
        previous_costs = results[k]
      else
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
      end
    end
    results
  end

  # need to consider budget policies (and balances), project end date
  # and when a cycle end/starts (unless continuous).
  def budget_changes(start_date, end_date)
    # Assume policies only change at the start of a billing cycle
    policy_dates = (start_date..end_date).to_a & active_billing_cycles
    policy_dates = [start_date] | policy_dates
    changes = {}
    policy_dates.each do |date|
      changes[date.to_s] = budget_on_date(date)
    end
    changes[@project.end_date.to_s] = 0.0 if @project.end_date && @project.end_date <= end_date
    changes
  end

  def budget_on_date(date)
    amount = 0.0
    policy = @project.budget_policies.where("effective_at <= ?", date).last
    return amount if !policy

    case policy.spend_profile
    when "fixed"
      amount = policy.cycle_limit
      # if not the start of a cycle, need to include spend this cycle so far
      if !active_billing_cycles.include?(date)
        amount -= costs_between_dates(start_of_billing_interval(date), date)
      end
    when "rolling"
      (cycle_number(date) * policy.cycle_limit) - costs_so_far(date)
    when "continuous"
      balance_amount(date) - costs_so_far(date)
    when "dynamic"
      (balance_amount(date) - costs_so_far(date)) / remaining_cycles(date)
    end
    amount
  end

  # The total amount, not including any spend so far
  def balance_amount(date)
    return 0.0 if date >= @project.end_date

    balance = @project.balances.where("effective_at <= ?", date).last
    balance ? balance.amount : 0.0
  end

  def costs_so_far(date)
    costs_between_dates(@project.start_date, date)
  end

  def costs_between_dates(start_date, end_date)
    logs = @project.cost_logs.where(scope: "total").where("date < ? AND date >= ?", end_date, start_date)
    logs.reduce(0.0) { |sum, log| sum + log.risk_cost }
  end

  def cycle_number(date)
    number = 0
    active_billing_cycles.each do |cycle|
      if cycle <= date
        number += 1
      else
        break
      end
    end
    number
  end

  # Includes the current cycle
  def remaining_cycles(date)
    active_billing_cycles.count - cycle_number(date)
  end

  def active_billing_cycles
    if !@cycles
      cycle = start_of_billing_interval(@project.start_date)
      if cycle > start_of_billing_interval(Date.today)
        @cycles = [cycle] 
        return @cycles
      end

      active_cycles = []
      if @project.end_date
        end_cycle = start_of_billing_interval(@project.end_date - 1.day)
      else
        end_cycle = end_of_billing_interval(Date.today) + 1.day
      end

      while (cycle <= end_cycle)
        active_cycles << cycle
        cycle = end_of_billing_interval(cycle) + 1.day
      end
      @cycles = active_cycles
    end
    @cycles
  end

  def start_of_billing_interval(date)
    if @project.cycle_interval == "monthly"
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
