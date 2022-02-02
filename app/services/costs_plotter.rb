class CostsPlotter

  def initialize(project)
    @project = project
  end

  def chart_cost_breakdown(start_date, end_date)
    cost_entries = cost_breakdown(start_date, end_date)
    dates = cost_entries.keys
    compute = []
    nodes = []
    data_out = []
    core = []
    core_storage = []
    other = []
    remaining_budget = []
    forecast_compute = []
    forecast_data_out = []
    forecast_core = []
    forecast_core_storage = []
    forecast_other = []
    forecast_remaining_budget = []
    compute_group_details = {actual: {}, forecast: {}}
    @project.front_end_compute_groups.keys.each do |group| 
      compute_group_details[:actual][group.to_sym] = []
      compute_group_details[:actual]["#{group}_storage".to_sym] = []
      compute_group_details[:forecast][group.to_sym] = []
      compute_group_details[:forecast]["#{group}_storage".to_sym] = []
    end
    first_forecast = true
    cost_entries.each do |k, v|
      break if @project.end_date && Date.parse(k) >= @project.end_date

      if v.has_key?(:compute)
        compute << v[:compute]
        data_out << v[:data_out]
        core << v[:core]
        core_storage << v[:core_storage]
        other << v[:other]
        remaining_budget << (Date.parse(k) < @project.start_date ? nil : v[:budget])
        forecast_compute << nil
        forecast_data_out << nil
        forecast_core_storage << nil
        forecast_core << nil
        forecast_other << nil
        forecast_remaining_budget << nil
        compute_group_details[:actual].keys.each {|group| compute_group_details[:actual][group] << v[group.to_sym]}
        compute_group_details[:forecast].keys.each {|group| compute_group_details[:forecast][group] << nil}
      else
        # to connect actual and forecast budget lines
        if first_forecast && forecast_remaining_budget.length > 0 && compute.any? &&
          v[:forecast_budget] && Date.parse(k) > @project.start_date
          first_forecast = false
          forecast_remaining_budget[-1] = v[:forecast_budget] + v[:forecast_total]
        end
        forecast_compute << v[:forecast_compute]
        forecast_data_out << v[:forecast_data_out]
        forecast_core << v[:forecast_core]
        forecast_core_storage << v[:forecast_core_storage]
        forecast_other << v[:forecast_other]
        forecast_remaining_budget << v[:forecast_budget]
        compute_group_details[:forecast].keys.each {|group| compute_group_details[:forecast][group] << v["forecast_#{group}".to_sym]}
      end
      nodes << v[:compute_nodes]
    end
    results = {'dates': dates, 'actual': {'any': remaining_budget.compact.length > 0, 'compute': compute, 
              'compute_groups': compute_group_details[:actual], 'data out': data_out, 'core': core, 'core_storage': core_storage,
              'other': other, 'remaining budget': remaining_budget}}
    results['forecast'] = {'any': forecast_remaining_budget.compact.length > 0, 'compute': forecast_compute,
                           'compute_groups': compute_group_details[:forecast], 'data out': forecast_data_out, 
                           'core': forecast_core, 'core_storage': forecast_core_storage, 'other': forecast_other,
                           'remaining budget': forecast_remaining_budget}
    results
  end

  def chart_cumulative_costs(start_date, end_date)
    start_of_cycle = start_of_billing_interval(start_date)
    cost_entries = cost_breakdown(start_of_cycle, end_date)
    dates = (start_date..end_date).map { |date| date.to_s }
    compute = []
    data_out = []
    core = []
    core_storage = []
    other = []
    overall = []
    budgets = []
    forecast_compute = []
    forecast_core = []
    forecast_data_out = []
    forecast_core_storage = []
    forecast_other = []
    forecast_overall = []
    main_datasets = [compute, core, core_storage, data_out, other, overall, budgets, forecast_compute, forecast_core,
                     forecast_core_storage, forecast_data_out, forecast_other, forecast_overall
                    ]
    compute_group_details = {actual: {}, forecast: {}}
    compute_group_totals = {}
    @project.front_end_compute_groups.keys.each do |group|
      compute_group_details[:actual][group.to_sym] = []
      compute_group_details[:actual]["#{group}_storage".to_sym] = []
      compute_group_details[:forecast][group.to_sym] = []
      compute_group_details[:forecast]["#{group}_storage".to_sym] = []
      compute_group_totals[group.to_sym] = 0.0
      compute_group_totals["#{group}_storage".to_sym] = 0.0
    end
    compute_total = 0.0
    core_total = 0.0
    data_out_total = 0.0
    core_storage_total = 0.0
    other_total = 0.0
    overall_total = 0.0
    budget_changes = budget_changes(start_of_cycle, end_date, true)
    budget = nil
    first_forecast = true
    cost_entries.each do |k, v|
      k = Date.parse(k)
      break if @project.end_date && k >= @project.end_date

      if k < @project.start_date
        main_datasets.each { |dataset| dataset << nil }
        compute_group_details[:actual].keys.each { |group| compute_group_details[:actual][group] << nil }
        compute_group_details[:forecast].keys.each { |group| compute_group_details[:forecast][group] << nil }
        next
      end
      # Reset totals to zero at start of each cycle
      if active_billing_cycles.include?(k)
        compute_total = 0.0
        core_total = 0.0
        data_out_total = 0.0
        core_storage_total = 0.0
        other_total = 0.0
        overall_total = 0.0
        compute_group_totals.keys.each { |key| compute_group_totals[key] = 0.0 }
      end
      if v.has_key?(:compute)
        compute_total += v[:compute]
        compute_group_totals.keys.each { |group| compute_group_totals[group] += v[group.to_sym] }
        core_total += v[:core]
        data_out_total += v[:data_out]
        core_storage_total += v[:core_storage]
        other_total += v[:other]
        overall_total += v[:total]

        if k >= start_date
          compute << compute_total
          compute_group_details[:actual].keys.each { |group| compute_group_details[:actual][group] << compute_group_totals[group] }
          data_out << data_out_total
          core << core_total
          core_storage << core_storage_total
          other << other_total
          overall << overall_total
          forecast_compute << nil
          compute_group_details[:forecast].keys.each { |group| compute_group_details[:forecast][group] << nil }
          forecast_core << nil
          forecast_data_out << nil
          forecast_core_storage << nil
          forecast_other << nil
          forecast_overall << nil
        end
      else
        if first_forecast == true && forecast_overall.length > 0 && k > @project.start_date
          first_forecast = false
          forecast_overall[-1] = overall_total
          forecast_other[-1] = other_total
          forecast_core_storage[-1] = core_storage_total
          forecast_data_out[-1] = data_out_total
          forecast_core[-1] = core_total
          compute_group_details[:forecast].keys.each {|group| compute_group_details[:forecast][group][-1] = compute_group_totals[group]}
        end
        compute_total += v[:forecast_compute]
        compute_group_totals.keys.each {|group| compute_group_totals[group] += v["forecast_#{group}".to_sym]}
        core_total += v[:forecast_core]
        data_out_total += v[:forecast_data_out]
        core_storage_total += v[:forecast_core_storage]
        other_total += v[:forecast_other]
        overall_total += v[:forecast_total]

        if k >= start_date
          forecast_compute << compute_total
          compute_group_details[:forecast].keys.each {|group| compute_group_details[:forecast][group] << compute_group_totals[group]}
          forecast_core << core_total
          forecast_data_out << data_out_total
          forecast_core_storage << core_storage_total
          forecast_other << other_total
          forecast_overall << overall_total
          compute << nil
          compute_group_details[:actual].keys.each { |group| compute_group_details[:actual][group] << nil }
          core << nil
          data_out << nil
          core_storage << nil
          other << nil
          overall << nil
        end
      end
      budget = budget_changes[k.to_s] if budget_changes.has_key?(k.to_s)
      if k >= start_date        
        budgets << budget
      end
    end

    results = {'dates': dates, 'actual': {'any': overall.compact.length > 0,'compute': compute, 'compute_groups': compute_group_details[:actual],
               'core': core, 'data out': data_out, 'core_storage': core_storage, 'other': other, 'total': overall}}
    results['forecast'] = {'any': forecast_overall.compact.length > 0, 'compute': forecast_compute, 'compute_groups': compute_group_details[:forecast],
                           'core': forecast_core,'data out': forecast_data_out, 'core_storage': forecast_core_storage, 'other': forecast_other, 
                           'total': forecast_overall}
    results['budget'] = budgets
    results
  end

  def cost_breakdown(start_date, end_date)
    results = {}
    compute_groups = @project.front_end_compute_groups
    (start_date..end_date).to_a.each do |date|
      if latest_cost_log_date && date <= latest_cost_log_date
        results[date.to_s] = { data_out: 0.0, core: 0.0, core_storage: 0.0, 
                              total: 0.0, other: 0.0, budget: 0.0,
                              compute: 0.0 }
        compute_groups.keys.each do |group|
          results[date.to_s][group.to_sym] = 0.0
          results[date.to_s]["#{group}_storage".to_sym] = 0.0
        end
      elsif @project.end_date && date >= @project.end_date || date < @project.start_date
        results[date.to_s] = {forecast_compute: nil, forecast_core: nil, forecast_data_out: nil,
                              forecast_core_storage: nil, forecast_total: nil,
                              forecast_other: nil, forecast_budget: nil}
        compute_groups.keys.each do |group|
          results[date.to_s]["forecast_#{group}".to_sym] = nil
          results[date.to_s]["forecast_#{group}_storage".to_sym] = nil
        end
      else
        results[date.to_s] = {forecast_compute: 0.0, forecast_data_out: 0.0, forecast_core: 0.0,
                              forecast_core_storage: 0.0, forecast_total: 0.0,
                              forecast_other: 0.0, forecast_budget: 0.0}
        compute_groups.keys.each do |group|
          results[date.to_s]["forecast_#{group}".to_sym] = 0.0
          results[date.to_s]["forecast_#{group}_storage".to_sym] = 0.0
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
    previous_costs = latest_previous_costs(start_date)
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
      elsif Date.parse(k) >= @project.start_date
        compute = 0.0
        compute_groups.keys.each do |group|
          results[k]["forecast_#{group}".to_sym] = forecast_compute_cost(Date.parse(k), group.to_sym)
          compute += results[k]["forecast_#{group}".to_sym]
          results[k]["forecast_#{group}_storage".to_sym] = previous_costs["#{group}_storage".to_sym]
          compute += results[k]["forecast_#{group}_storage".to_sym]
        end
        results[k][:forecast_compute] = compute
        results[k][:forecast_data_out] = previous_costs[:data_out]
        results[k][:forecast_core] = previous_costs[:core]
        results[k][:forecast_core_storage] = previous_costs[:core_storage]
        results[k][:forecast_total] = previous_costs[:total] - previous_costs[:compute] + compute
        results[k][:forecast_other] = results[k][:forecast_total] - (compute + previous_costs[:data_out] + previous_costs[:core] + previous_costs[:core_storage])
        results[k][:forecast_other] = 0 if results[k][:forecast_other] < 0 # due to rounding if very small numbers
        total += results[k][:forecast_total]
        results[k][:forecast_budget] = budget - total
      end
    end
    results
  end

  # For forecasts we use the latest amount (except for compute group instance costs)
  def latest_previous_costs(date)
    costs = {compute: 0.0, data_out: 0.0, core: 0.0, core_storage: 0.0, total: 0.0, other: 0.0}
    @project.front_end_compute_groups.keys.each do |group|
      costs[group.to_sym] = 0.0
      costs["#{group}_storage".to_sym] = 0.0
    end

    date =  latest_cost_log_date && date > latest_cost_log_date ? latest_cost_log_date : date - 1.day
    return costs if !date

    logs = @project.cost_logs.where(date: date.to_s)
    logs.each do |log|
      costs[log.scope.to_sym] = log.risk_cost
    end
    costs
  end

  # Just instance costs
  def forecast_compute_cost(date, group=nil)
    total = 0.0
    if date > Date.today
      group ||= :total
      return current_compute_costs[group]
    else
      instance_logs = @project.instance_logs.where(date: date.to_s)
      instance_logs = instance_logs.where(compute_group: group) if group
      # In case no logs recored on that day, use previous
      instance_logs = most_recent_instance_logs(date, group) if !instance_logs.any?
      total = instance_logs.reduce(0.0) { |sum, log| sum + log.actual_cost }
    end
    total
  end

  def most_recent_instance_logs(date, group=nil)
    latest_date = @project.instance_logs.where("date < ?", date).maximum(:date)
    logs = @project.instance_logs.where(date: latest_date)
    logs = @project.latest_instance_logs if !logs.any?
    logs = logs.where(compute_group: group) if group
    logs
  end

  # Just instance costs
  def current_compute_costs
    if !@current_compute_costs
      @current_compute_costs = {total: 0.0}
      @project.latest_instances.each do |group, instances|
        @current_compute_costs[group.to_sym] = 0.0
        instances.each do |instance|
          cost = instance.total_daily_compute_cost
          @current_compute_costs[group.to_sym] += cost
          @current_compute_costs[:total] += cost
        end
      end
    end
    @current_compute_costs
  end

  def latest_compute_storage_costs
    if !@current_compute_storage_costs
      logs = @project.cost_logs.where(compute: true, date: latest_cost_log_date).where(
                                              "scope LIKE '%storage%'")
      @current_compute_storage_costs = logs.reduce(0.0) { |sum, log| sum + log.risk_cost }
    end
    @current_compute_storage_costs
  end

  def latest_non_compute_costs
    if !@latest_non_compute_costs
      @latest_non_compute_costs = 0
      if latest_cost_log_date
        total_log = @project.cost_logs.find_by(scope: "total", date: latest_cost_log_date)
        total_amount = total_log ? total_log.risk_cost : 0.0
        compute_logs = @project.cost_logs.where(compute: true, date: latest_cost_log_date)
        compute_amount = compute_logs.reduce(0.0) { |sum, log| sum + log.risk_cost }
        @latest_non_compute_costs = total_amount - compute_amount
      end 
    end
    @latest_non_compute_costs
  end

  # need to consider budget policies (and balances), project end date
  # and when a cycle end/starts (unless continuous).
  def budget_changes(start_date, end_date, for_cumulative_chart=false)
    # Assume policies only change at the start of a billing cycle
    policy_dates = (start_date..end_date).to_a & active_billing_cycles
    policy_dates = [start_date] | policy_dates
    changes = {}
    policy_dates.each do |date|
      changes[date.to_s] = budget_on_date(date, for_cumulative_chart)
    end
    changes[@project.end_date.to_s] = 0.0 if @project.end_date && @project.end_date <= end_date
    changes
  end

  def budget_on_date(date, for_cumulative_chart=false)
    amount = 0.0
    policy = @project.budget_policies.where("effective_at <= ?", date).last
    return amount if !policy

    case policy.spend_profile
    when "fixed"
      amount = policy.cycle_limit
      # if not the start of a cycle, need to include spend this cycle so far
      if !active_billing_cycles.include?(date) && !for_cumulative_chart
        amount -= costs_between_dates(start_of_billing_interval(date), date)
      end
    when "rolling"
      amount = (cycle_number(date) * policy.cycle_limit) - costs_so_far(date)
    when "continuous"
      amount = balance_amount(date) - costs_so_far(date)
    when "dynamic"
      amount = (balance_amount(date) - costs_so_far(date)) / remaining_cycles(date)
    end
    amount
  end

  # The total amount, not including any spend so far
  def balance_amount(date)
    return 0.0 if @project.end_date && date >= @project.end_date

    balance = @project.balances.where("effective_at <= ?", date).last
    balance ? balance.amount : 0.0
  end

  def costs_so_far(date)
    costs_between_dates(@project.start_date, date)
  end

  def costs_between_dates(start_date, end_date)
    logs = @project.cost_logs.where(scope: "total").where("date < ? AND date >= ?", end_date, start_date)
    costs = logs.reduce(0.0) { |sum, log| sum + log.risk_cost }
    latest_actual = latest_cost_log_date ? latest_cost_log_date + 1.day : @project.start_date
    if end_date > latest_actual
      (latest_actual...end_date).to_a.each do |date|
        costs += forecast_compute_cost(date)
        costs += latest_compute_storage_costs
        costs += latest_non_compute_costs
      end
    end
    costs
  end

  def latest_cost_log_date
    @latest_cost_log_date ||= @project.cost_logs.last&.date
  end

  def cycle_ends(start_date, end_date)
    ends = []
    (start_date..(end_date + 1.day)).to_a.each_with_index do |date, index|
      if active_billing_cycles.include?(date) && index > 1 && date != active_billing_cycles.first
        ends << index - 1
      end
    end
    ends
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
    elsif @project.cycle_interval == "custom"
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
    if @project.cycle_interval == "monthly"
      start_of_billing_interval(date + 1.month + 4.days) - 1.day
    elsif @project.cycle_interval == "weekly"
      start_of_billing_interval(date + 1.week) - 1.day
    else
      start_of_billing_interval(date + @project.cycle_days.days) - 1.day
    end
  end

  def billing_start_day_of_month
    1
  end

  def billing_start_day_of_week
    @project.start_date.wday
  end

  def possible_datasets
    datasets = @project.front_end_compute_groups.keys
    datasets ||= []
    datasets += [ "budget", "core", "cycle total", "data out", "other"]
    datasets
  end
end
