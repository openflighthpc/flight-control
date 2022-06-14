class CostsPlotter

  def initialize(project)
    @project = project
  end

  def chart_cost_breakdown(start_date, end_date, temp_change_request=nil, cost_entries=nil)
    cost_entries ||= cost_breakdown(start_date, end_date, temp_change_request)
    dates = []
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
      next if Date.parse(k) < start_date || Date.parse(k) > end_date
      dates << k
      break if @project.archived_date && Date.parse(k) >= @project.archived_date

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
        if first_forecast && forecast_remaining_budget.length > 0 && remaining_budget.any? &&
          v[:forecast_budget] && Date.parse(k) > @project.start_date
          first_forecast = false
          forecast_remaining_budget[-1] = remaining_budget[-1]
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
              'compute_groups': compute_group_details[:actual], 'data out': data_out, 'core': core, 'core storage': core_storage,
              'other': other, 'remaining budget': remaining_budget}}
    results['forecast'] = {'any': forecast_remaining_budget.compact.length > 0, 'compute': forecast_compute,
                           'compute_groups': compute_group_details[:forecast], 'data out': forecast_data_out, 
                           'core': forecast_core, 'core storage': forecast_core_storage, 'other': forecast_other,
                           'remaining budget': forecast_remaining_budget}
    results
  end

  def total_costs_this_cycle(compute_groups)
    start_date = start_of_current_billing_interval
    end_date = [Date.yesterday, start_date].max
    cost_entries = cost_breakdown(start_date, end_date)
    compute_groups.dup.each { |group| compute_groups << "#{group}_storage" }

    total_costs = {}
    compute_groups.each do |group|
      total_costs[group.to_sym] = 0
      cost_entries.each do |k, v|
        k = Date.parse(k)
        break if (@project.archived_date && k >= @project.archived_date) || k > end_date
        total_costs[group.to_sym] += v.has_key?(:compute) ? v[group.to_sym] : v["forecast_#{group}".to_sym]
      end
    end
    total_costs
  end

  def chart_cumulative_costs(start_date, end_date, temp_change_request=nil, cost_entries=nil)
    start_of_cycle = start_of_billing_interval(start_date)
    cost_entries ||= cost_breakdown(start_of_cycle, end_date, temp_change_request)
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
      break if @project.archived_date && k >= @project.archived_date
      break if k > end_date

      if k < @project.start_date
        main_datasets.each { |dataset| dataset << nil }
        compute_group_details[:actual].keys.each { |group| compute_group_details[:actual][group] << nil }
        compute_group_details[:forecast].keys.each { |group| compute_group_details[:forecast][group] << nil }
        next
      end
      if v.has_key?(:compute)
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

      if @project.end_date && k >= @project.end_date
        budget = 0.0
      elsif budget_changes.has_key?(k.to_s)
        budget = budget_changes[k.to_s]
      end

      if k >= start_date      
        budgets << budget
      end
    end

    results = {'dates': dates, 'actual': {'any': overall.compact.length > 0,'compute': compute, 'compute_groups': compute_group_details[:actual],
               'core': core, 'data out': data_out, 'core storage': core_storage, 'other': other, 'total': overall}}
    results['forecast'] = {'any': forecast_overall.compact.length > 0, 'compute': forecast_compute, 'compute_groups': compute_group_details[:forecast],
                           'core': forecast_core,'data out': forecast_data_out, 'core storage': forecast_core_storage, 'other': forecast_other, 
                           'total': forecast_overall}
    results['budget'] = budgets
    results
  end

  # break costs into cycles. Allows for calculating over budget switch offs
  # across multiple cycles
  def combined_cost_breakdown(start_date, end_date, change_request=nil, match_buget=false)
    start_of_current_cycle = start_of_billing_interval(Date.current)
    if start_date < start_of_current_cycle
      start = start_of_billing_interval(start_date)
    else
      start = start_of_current_cycle
    end
    end_date = end_of_billing_interval(end_date)
    covered_cycles = []
    date_range = (start..end_date).to_a
    active_billing_cycles.each do |start_of_cycle|
      covered_cycles << start_of_cycle if date_range.include?(start_of_cycle)
    end
    all_costs = {}
    covered_cycles.each do |start_of_cycle|
      end_of_cycle = end_of_billing_interval(start_of_cycle)
      cycle_costs = cost_breakdown(start_of_cycle, end_of_cycle, nil, true)
      all_costs = all_costs.deep_merge(cycle_costs)
    end
    all_costs
  end

  def cost_breakdown(start_date, end_date, change_request=nil, match_budget=false)
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
      elsif @project.archived_date && date >= @project.archived_date || date < @project.start_date
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
      break if @project.archived_date && Date.parse(k) >= @project.archived_date

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
        compute = 0.0
        compute_groups.keys.each do |group|
          results[k]["forecast_#{group}".to_sym] = forecast_compute_cost(Date.parse(k), group.to_sym, change_request)
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
    if match_budget
      results = prioritise_to_budget(start_date, end_date, change_request, results)
    end
    results
  end

  def prioritise_to_budget(start_date, end_date, change_request, results)
    end_costs = results.to_a.last[1]
    return results if !end_costs[:forecast_budget]
    instances_off = prioritisation_actions(results)
    return results if !instances_off || instances_off.empty?

    # Maybe this should be performed by the instance tracker
    @project.latest_instances.map {|group, instances| instances}.flatten.each do |instance|
      if instances_off.dig(instance.group, instance.instance_type, :off)
        instance.add_budget_switch_offs(instances_off[instance.group][instance.instance_type][:off])
      end
    end

    compute_groups = @project.front_end_compute_groups.keys
    remaining_budget = nil
    results.each do |date, costs|
      if costs[:forecast_budget]
        if !remaining_budget
          remaining_budget = costs[:forecast_budget] + costs[:forecast_total]
        end
        original_non_compute_total = costs[:forecast_total] - costs[:forecast_compute] 
        compute_total = 0.0
        compute_groups.each do |group|
          results[date]["forecast_#{group}".to_sym] = forecast_compute_cost(Date.parse(date), group.to_sym, change_request)
          compute_total += results[date]["forecast_#{group}".to_sym]
          compute_total += results[date]["forecast_#{group}_storage".to_sym]
        end
        results[date][:forecast_compute] = compute_total
        results[date][:forecast_total] = original_non_compute_total + compute_total
        remaining_budget -= results[date][:forecast_total]
        results[date][:forecast_budget] = remaining_budget 
      end
    end
    results
  end

  def prioritisation_actions(results)
    end_costs = results.to_a.last[1]
    budget_diff = end_costs[:forecast_budget]
    return nil if !budget_diff || budget_diff >= 0
    
    last_date = Date.parse(results.keys.last)
    future_days = [last_date - Date.current, 0].max.to_i
    first_date = Date.parse(results.keys.first)
    future_cycle_days = [first_date - Date.current, 0].max.to_i
    end_of_cycle = last_date
    prioritised_instances = @project.latest_instances.map {|group, instances| instances}.flatten.sort
    instances_off = {}
    @project.latest_instances.each do |group, instances|
      instances_off[group] = {}
      instances.each {|instance| instances_off[group][instance.instance_type] = {}}
    end
    
    i = 0
    while i < prioritised_instances.length && budget_diff < 0
      instance = prioritised_instances[i]
      group = instance.group
      type = instance.instance_type
      original_switch_offs = convert_to_count(instances_off[group][type][:off]) || {}

      days = future_days
      switch_off_date = last_date
      last_switch_off_day = nil
      beginning_budget_diff = budget_diff
      # instance costs can vary day by day based on scheduled requests
      # and so the impact of a switch off on future days must be calculated

      while budget_diff < 0 && days > 0 && days > future_cycle_days
        days -= 1
        switch_off_date = switch_off_date - 1.day
        if instance.pending_on_date_end(switch_off_date, original_switch_offs) > 0
          last_switch_off_day = days # earlier days it may not actually be on yet
          original_cost_until_end_of_cycle = instance.projected_costs_with_budget_switch_offs(original_switch_offs, switch_off_date, end_of_cycle)
          switch_offs = Project.deep_copy_hash(original_switch_offs)
          switch_offs[switch_off_date] = {Project::BUDGET_SWITCH_OFF_TIME => {count: 0, min: false}}
          cost_until_end_of_cycle = instance.projected_costs_with_budget_switch_offs(switch_offs, switch_off_date, end_of_cycle)
          difference = original_cost_until_end_of_cycle - cost_until_end_of_cycle
          budget_diff = beginning_budget_diff + difference
        end
      end
      if last_switch_off_day
        on = instance.pending_on_date_end(Date.current + last_switch_off_day.days)
        if instances_off[group][type][:off]
          instances_off[group][type][:off][last_switch_off_day] = on
        else
          instances_off[group][type][:off] = {last_switch_off_day => on}
        end
        # Repeat if still over budget, and there are requests that might
        # switch this back on again
        if budget_diff < 0
          next
        end
      else
        i += 1
        next
      end

      # if enough budget remaining, don't turn off so many instances,
      # or turn one off later
      original_switch_offs = Project.deep_copy_hash(switch_offs)
      original_switch_off_date = Date.current + last_switch_off_day.days
      if instances_off[group][type][:off] && !instances_off[group][type][:off].empty? && budget_diff > 0 && on > 1
        off_dates = Project.deep_copy_hash(instances_off[group][type][:off])
        new_off, new_budget_diff = minimise_switch_offs(instance, off_dates, budget_diff, future_days, future_cycle_days)
        if new_budget_diff != budget_diff && new_budget_diff >= 0
          budget_diff = new_budget_diff
          instances_off[group][type][:off] = new_off
        end
      end
      i += 1
    end

    #if shutting off higher priority node(s) leaves a surplus budget (that
    #is too little for this node to add a day), see if this means lower
    #priority nodes can be turned off later.
    i -= 1
    while budget_diff > 0 && i > 0
      lower_priority_instance = prioritised_instances[i - 1]
      group = lower_priority_instance.group
      type = lower_priority_instance.instance_type
      off_dates = Project.deep_copy_hash(instances_off[group][type][:off])
      if instances_off[group][type][:off] && !instances_off[group][type][:off].empty?
        new_off, new_budget_diff = minimise_switch_offs(lower_priority_instance, off_dates, budget_diff, future_days, future_cycle_days)
        if new_budget_diff != budget_diff && budget_diff >= 0
          budget_diff = new_budget_diff
          instances_off[group][type][:off] = new_off
        end
      end
      i -= 1;
    end
    instances_off.select! {|group, instance_types| instance_types.any? {|type, off| off.any? }}
    instances_off
  end

  def convert_to_count(instances_off)
    return {} if !instances_off
    as_count = {}
    instances_off.each do |index, count|
      as_count[Date.current + index.days] = {Project::BUDGET_SWITCH_OFF_TIME => {count: 0, min: false}}
    end
    as_count
  end

  def minimise_switch_offs(instance, instances_off, budget_diff, future_days, future_cycle_days)
    return instances_off, budget_diff if budget_diff <= 0 || instances_off.empty?
    end_of_cycle = Date.current + future_days.days
    original_switch_offs = convert_to_count(instances_off)
    new_switch_offs = Project.deep_copy_hash(original_switch_offs)
    last_switch_off_day = nil

    instances_off.reverse_each do |original_days_in_future, off|
      beginning_budget_diff = budget_diff
      off.times do |x|
        break if budget_diff <= 0 || (x > 0 && last_switch_off_day && (last_switch_off_day <= future_days || last_switch_off_day <= future_cycle_days)) ||
        new_switch_offs.empty?

        last_switch_off_day = nil
        last_switch_off_date = nil
        new_days = original_days_in_future
        original_switch_off_date = Date.current + original_days_in_future
        switch_off_date = original_switch_off_date
        count_start_schedules = Project.deep_copy_hash(new_switch_offs)
        count_start_budget_diff = budget_diff;
        on = instance.pending_on_date_end(original_switch_off_date, original_switch_offs)
        new_switch_offs[original_switch_off_date][Project::BUDGET_SWITCH_OFF_TIME][:count] += 1
        if new_switch_offs[original_switch_off_date][Project::BUDGET_SWITCH_OFF_TIME][:count] >= off
          new_switch_offs.delete(original_switch_off_date)
        end

        previous_switch_offs = Project.deep_copy_hash(new_switch_offs)
        while budget_diff > 0 && new_days <= future_days
          temp_switch_offs = Project.deep_copy_hash(new_switch_offs)
          new_days += 1;
          switch_off_date = switch_off_date + 1.day
          currently_on = instance.pending_on_date_end(switch_off_date, new_switch_offs)
          if currently_on > 0
            if temp_switch_offs.has_key?(switch_off_date)
              if temp_switch_offs[switch_off_date][Project::BUDGET_SWITCH_OFF_TIME][:count] < currently_on
                temp_switch_offs[switch_off_date][Project::BUDGET_SWITCH_OFF_TIME][:count] += 1
              end
            else
              temp_switch_offs[switch_off_date] = {Project::BUDGET_SWITCH_OFF_TIME => {count: currently_on - 1, min: false}}
            end
          else
            temp_switch_offs = previous_switch_offs
          end
          start_date = [Date.current, end_of_cycle].min
          original_cost_until_end_of_cycle = instance.projected_costs_with_budget_switch_offs(original_switch_offs, start_date, end_of_cycle)
          cost_until_end_of_cycle = instance.projected_costs_with_budget_switch_offs(temp_switch_offs, start_date, end_of_cycle)
          difference = original_cost_until_end_of_cycle - cost_until_end_of_cycle
          budget_diff = beginning_budget_diff + difference
          # don't use if means going over budget, or no instances to turn off that day
          if budget_diff >= 0 && currently_on > 0 && budget_diff < beginning_budget_diff
            last_switch_off_date = switch_off_date
            last_switch_off_day = new_days
            previous_switch_offs = temp_switch_offs
            last_budget_diff = budget_diff
          end
        end

        # Would be easier to understand if we weren't switching back and forth between
        # formats
        if last_switch_off_day
          if last_switch_off_day < future_days
            existing_on = instance.pending_on_date_end(last_switch_off_date, previous_switch_offs, false)
            if instances_off.has_key?(last_switch_off_day) &&
              instances_off[last_switch_off_day] < existing_on
              instances_off[last_switch_off_day] += 1
            elsif existing_on > 0
              instances_off[last_switch_off_day] = 1
            end
          end
          instances_off[original_days_in_future] -= 1
          instances_off.delete(original_days_in_future) if instances_off[original_days_in_future] == 0
          budget_diff = last_budget_diff
        else
          previous_switch_offs = count_start_schedules
          budget_diff = count_start_budget_diff
        end
      end
    end

    return instances_off, budget_diff
  end

  # For forecasts we use the latest amount (except for compute group instance costs)
  def latest_previous_costs(date)
    costs = {compute: 0.0, data_out: 0.0, core: 0.0, core_storage: 0.0, total: 0.0, other: 0.0}
    @project.front_end_compute_groups.keys.each do |group|
      costs[group.to_sym] = 0.0
      costs["#{group}_storage".to_sym] = 0.0
    end

    date = latest_cost_log_date && date > latest_cost_log_date ? latest_cost_log_date : date - 1.day
    return costs if !date

    logs = @project.cost_logs.where(date: date.to_s)
    logs.each do |log|
      cost = log.risk_cost
      costs[log.scope.to_sym] = cost
      costs[:compute] += cost if log.compute
    end
    costs
  end

  # Just instance costs
  def forecast_compute_cost(date, group=nil, temp_change_request=nil)
    total = 0.0
    if date > Date.current
      group ||= :total
      # return temp_change_request || @project.pending? ? pending_compute_costs(date)[group] : current_compute_costs[group]
      return pending_compute_costs(date)[group]
    end

    # To be consistent with rounding, etc. for overall total we need to calculate groups
    # individually.
    if !group
      @project.front_end_compute_groups.keys.each do |group|
        total += forecast_compute_cost(date, group, temp_change_request)
      end
      return total
    end

    actions = @project.action_logs.where(date: date)
    scheduled_actions = @project.pending_one_off_and_repeat_requests_on(date.to_s)
    if temp_change_request
      if temp_change_request.actual_or_parent_id
        scheduled_actions = scheduled_actions.select { |scheduled| scheduled.actual_or_parent_id != temp_change_request.actual_or_parent_id }
      end
      if temp_change_request.action_on_date?(date.to_s)
        temp_as_one_off = temp_change_request.individual_request_on_date(date.to_s)
        # If temp request is a one off we need to reset comparison counts so accurately
        # determining temporary switch ons/ offs
        temp_as_one_off.reset_comparison_counts
        scheduled_actions = scheduled_actions << temp_as_one_off
      end
    end
    scheuled_actions = scheduled_actions.select { |scheduled| scheduled.counts[group.to_s]}
    instance_logs = @project.instance_logs.where(date: date.to_s).where(compute_group: group)
    # In case no logs recorded on that day, use previous
    instance_logs = most_recent_instance_logs(date, group) if !instance_logs.any?
    if actions.any? || scheduled_actions.any?
      instance_logs.each do |log|
        instance_cost = 0.0
        instance_actions = actions.where(instance_id: log.instance_id).reorder(:actioned_at)
        instance_scheduled = scheduled_actions.select do |schedule| 
          schedule.counts[log.compute_group] && schedule.counts[log.compute_group][log.instance_type]
        end
        instance_scheduled.sort_by! { |scheduled| scheduled.time }
        previous_time = date.to_time # start of day (00:00)
        previous_action = nil
        # we can calculate running time by comparing action log times and actions
        time_on = 0
        if instance_actions.any? || instance_scheduled.any?
          instance_actions.each do |action|
            original_status = action.action == "on" ? "off" : "on"
            time_at_previous_status = (action.actioned_at - previous_time) / 3600 # in hours
            time_on += time_at_previous_status.ceil if original_status == "on"
            previous_time = action.actioned_at
            previous_action = action.action
          end
          previous_action = log.pending_on? ? "on" : "off" if !instance_actions.any?
          instance_scheduled.each do |schedule|
            action = schedule.check_and_update_target_counts(log.compute_group, log.instance_type, previous_action)
            if action
              time_at_previous_status = (schedule.date_time - previous_time) / 3600 # in hours
              time_on += time_at_previous_status.ceil if previous_action == "on"
              previous_time = schedule.date_time
              previous_action = action   
            end
          end
          to_end_of_day = ((date + 1.day).to_time - previous_time) / 3600
          time_on += to_end_of_day.ceil if previous_action == "on"
          time_on = [time_on, 24].min
          instance_cost += log.hourly_compute_cost * time_on.ceil
        else
          # no changes so can use instance log status
          if date == Date.current # handles if a pending action log from yesterday
            instance_cost = log.daily_compute_cost if log.pending_on?
          else
            instance_cost = log.daily_compute_cost if log.on?
          end
        end
        total += instance_cost
      end
      total = total.ceil
    else
      if date == Date.current # handles if a pending action log from yesterday
        instance_logs = instance_logs.select { |log| log.pending_on? }
        total = instance_logs.reduce(0.0) { |sum, log| sum + log.daily_compute_cost }
      else
        total = instance_logs.reduce(0.0) { |sum, log| sum + log.actual_cost }
      end
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
  def pending_compute_costs(date=Date.current)
    pending_compute_costs = {total: 0.0}
    @project.latest_instances.each do |group, instances|
      pending_compute_costs[group.to_sym] = 0.0
      instances.each do |instance|
        cost = instance.pending_daily_cost_with_future_counts(date)
        pending_compute_costs[group.to_sym] += cost
        pending_compute_costs[:total] += cost
      end
    end
    pending_compute_costs
  end

  # Just instance costs
  def current_compute_costs
    if !@current_compute_costs
      @current_compute_costs = {total: 0.0}
      @project.latest_instances.each do |group, instances|
        @current_compute_costs[group.to_sym] = 0.0
        instances.each do |instance|
          cost = instance.pending_total_daily_compute_cost
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

  # This will now be based on cycle starts, funds transfers and balances (for some policy types)
  def budget_changes(start_date, end_date, for_cumulative_chart=false)
    # Assume policies only change at the start of a billing cycle
    budget_dates = (start_date..end_date).to_a & active_billing_cycles
    budget_dates = [start_date] | budget_dates
    budget_dates << @project.start_date if @project.start_date < end_date
    changes = {}
    budget_dates.each do |date|
      break if @project.end_date && date >= @project.end_date && date != start_date
      changes[date.to_s] = budget_on_date(date, for_cumulative_chart)
    end
    changes[@project.end_date.to_s] = 0.0 if @project.end_date && @project.end_date <= end_date
    changes
  end

  # Balance of compute units received - compute units
  def control_balance_on_date(date)
    @project.funds_transfer_requests.completed.where("date <= ?", date).sum(:signed_amount)
  end

  # At start of cycle. Assume balance is hub's balance and it is up to date
  def required_budget_for_cycle(cycle_start_date)
    return nil if @project.end_date && cycle_start_date >= @project.end_date

    policy = @project.budget_policies.where("effective_at <= ?", cycle_start_date).last
    return nil if !policy

    amount = 0.0
    case policy.spend_profile
    when "fixed"
      amount = policy.cycle_limit
    when "rolling"
      amount = (cycle_number(cycle_start_date) * policy.cycle_limit) - costs_so_far(cycle_start_date)
    when "continuous"
      amount = balance_amount(cycle_start_date)
    when "dynamic"
      remaining = remaining_cycles(cycle_start_date)
      if remaining < 1
        amount = nil
      else
        amount = ((balance_amount(cycle_start_date)) / remaining).floor
      end
    end
    amount
  end

  # For past cycles and current cycle, this should be based on actual
  # balance of compute units received.
  def budget_on_date(date, for_cumulative_chart=false)
    amount = 0.0
    if @project.end_date && date >= @project.end_date
      if date == @project_end_date
        return amount
      else
        return amount - costs_between_dates(@project.end_date, date)
      end
    end

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
      remaining = remaining_cycles(date)
      if remaining < 1
        amount = 0
      else
        amount = ((balance_amount(date) - costs_so_far(date)) / remaining).floor
      end
    end
    amount
  end

  # The total amount, not including any spend so far
  def balance_amount(date)
    return 0.0 if @project.archived_date && date >= @project.archived_date

    balance = @project.balances.where("effective_at <= ?", date).last
    balance ? balance.amount : 0.0
  end

  def remaining_balance(date)
    balance_amount(date) - costs_so_far(date)
  end

  def costs_so_far(date)
    costs_between_dates(@project.start_date, date)
  end

  # Does not include end date or over budget switch offs
  def costs_between_dates(start_date, end_date)
    logs = @project.cost_logs.where(scope: "total").where("date < ? AND date >= ?", end_date, start_date)
    costs = logs.reduce(0.0) { |sum, log| sum + log.risk_cost }
    latest_actual = latest_cost_log_date ? latest_cost_log_date + 1.day : @project.start_date
    if end_date > latest_actual
      (([start_date, latest_actual].max)...end_date).to_a.each do |date|
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

  def estimated_balance_end_in_cycle(start_date=start_of_current_billing_interval,
                                     end_date=end_of_current_billing_interval,
                                     costs=nil,
                                     temp_change_request=nil)
    costs ||= combined_cost_breakdown(start_date, end_date, temp_change_request, true)
    balance = @project.balances.where("amount > ?", 0).last
    balance = balance ? balance.amount : 0.0
    date_grouped = @project.cost_logs.where(scope: "total").group_by { |log| log.date }
    balance_end_date = @project.start_date
    date_grouped.each do |date, logs|
      balance -= logs.reduce(0.0) { |sum, log| sum + log.risk_cost }
      balance_end_date = date
      break if balance <= 0
    end

    if balance > 0 && balance_end_date < end_date
      # Need to set a final date to avoid possibility of infinite/ very long loop if costs
      # are zero/ very low
      final_check_date = end_date
      while(balance > 0 && balance_end_date <= final_check_date)
        balance_end_date += 1.day
        day_costs = costs[balance_end_date.to_s]
        next if !day_costs

        total_day_cost = day_costs[:total] ? day_costs[:total] : day_costs[:forecast_total]
        balance -= total_day_cost
      end
      balance_end_date = nil if balance_end_date > final_check_date
    end

    cycle_index = nil
    if balance_end_date && balance_end_date >= start_date && balance_end_date <= end_date
      cycle_index = (start_date..end_date).to_a.index(balance_end_date)
    end
    {cycle_index: cycle_index, over: balance < 0, end_balance: balance}
  end

  def cycle_thresholds(start_date, end_date)
    thresholds = []
    (start_date..(end_date + 1.day)).to_a.each_with_index do |date, index|
      if (date == @project.start_date)
        thresholds << { index: index, type: "Project start" }
      elsif (active_billing_cycles.include?(date) || date == @project.end_date) &&
          index > 0 && date != active_billing_cycles.first
        thresholds << { index: index - 1, type: (date == @project.end_date ? "Project end" : "Cycle end") }
      end 
    end
    thresholds
  end

  def latest_cycle_details
    details = historic_cycle_details.detect {|cycle| cycle[:current] }
    if !details
      details = {starting_balance: balance_amount(Date.current), costs: 0,
                 costs_so_far: 0}
    end
    details[:length] = @project.current_budget_policy.cycle_length
    details
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

  # Includes the current cycle and does not include cycles after project end date
  def remaining_cycles(date)
    cycles = active_billing_cycles
    cycles = cycles.select { |cycle| cycle < @project.end_date} if @project.end_date
    cycles.count - cycle_number(date) + 1
  end

  def active_billing_cycles
    if !@cycles
      cycle = start_of_billing_interval(@project.start_date)
      if cycle > start_of_billing_interval(Date.current)
        @cycles = [cycle] 
        return @cycles
      end

      active_cycles = []
      if @project.archived_date
        end_cycle = start_of_billing_interval(@project.archived_date - 1.day)
      else
        end_cycle = end_of_billing_interval(Date.current + 1.year) + 1.day
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
      start_of_billing_interval(date + 1.month) - 1.day
    elsif @project.cycle_interval == "weekly"
      start_of_billing_interval(date + 1.week) - 1.day
    else
      start_of_billing_interval(date + @project.cycle_days.days) - 1.day
    end
  end

  def start_of_current_billing_interval
    start_of_billing_interval(Date.current)
  end

  def end_of_current_billing_interval
    end_of_billing_interval(Date.current)
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

  def recalculate_costs_and_switch_offs(end_date=nil)
    @project.reset_latest_instances
    start_date = start_of_current_billing_interval
    end_date ||= end_of_billing_interval(start_date)
    combined_cost_breakdown(start_date, end_date, nil, true)
  end

  def switch_off_details(index_date=start_of_current_billing_interval, recalculate=true)
    recalculate_costs_and_switch_offs if recalculate
    switch_offs = {}
    @project.latest_instances.each do |group, instance_types|
      instance_types.each do |instance|
        off = instance.budget_switch_offs
        if off.any?
          switch_offs[group] = {} if !switch_offs[group]
          off_using_relative_index = {}
          off.each do |date, number_off|
            days_after_index_date = (date - index_date).to_i
            off_using_relative_index[days_after_index_date] = number_off if days_after_index_date >= 0
          end
          switch_offs[group][instance.instance_type] = off_using_relative_index
        end
      end
    end
    switch_offs
  end

  def front_end_switch_offs_by_date(
    index_date=start_of_current_billing_interval,
    end_date=end_of_current_billing_interval,
    recalculate=true
  )
    front_end_switch_offs = {}
    switch_offs = switch_off_details(index_date, recalculate)
    end_date_index = (end_date - index_date).to_i
    switch_offs.each do |group, details|
      details.each do |instance_type, off_using_relative_index|
        customer_facing_type = InstanceMapping.customer_facing_type(@project.platform, instance_type)
        off_using_relative_index.each do |i, off|
          next if i > end_date_index

          if front_end_switch_offs[i]
            front_end_switch_offs[i] << "#{off}x #{group} #{customer_facing_type} off"
          else
            front_end_switch_offs[i] = ["#{off}x #{group} #{customer_facing_type} off"]
          end
        end
      end
    end
    front_end_switch_offs
  end  

  def front_end_switch_off_details(index_date=start_of_current_billing_interval, recalculate=true, customer_facing=true)
    front_end_switch_offs = {}
    switch_offs = switch_off_details(index_date, recalculate)
    switch_offs.each do |group, details|
      details.each do |instance_type, off_using_relative_index|
        if off_using_relative_index.any?
          instance_type = InstanceMapping.customer_facing_type(@project.platform, instance_type) if customer_facing
          front_end_switch_offs["#{group} #{instance_type}"] = off_using_relative_index
        end
      end
    end
    front_end_switch_offs
  end

  def switch_off_schedule_msg(recalculate=true, customer_facing=true)
    off_msg = nil
    start_date = start_of_current_billing_interval
    switch_offs = front_end_switch_off_details(start_date, recalculate, customer_facing)
    if switch_offs.any?
      off_msg = ""
      off_details = []
      switch_offs.each do |instance, details|
        details.each do |days_in_future, off|
          off_details << ["#{off} #{instance}", days_in_future]
        end
      end
      off_details.sort_by! {|details| [details[1], details[0]]}
      off_details.each do |details|
        date = start_date + details[1].days
        off_msg << "Turn off #{details[0]} by end of #{date}#{" (today)" if date == Date.current}\n"
      end
    end
    off_msg
  end

  def today_budget_switch_offs
    recalculate_costs_and_switch_offs
    switch_offs = {}
    @project.latest_instances.each do |group, instance_types|
      instance_types.each do |instance|
        off_today = instance.budget_switch_offs[Date.current]
        if off_today
          if switch_offs[group]
            switch_offs[group][instance.instance_type] = off_today
          else
            switch_offs[group] = {instance.instance_type => off_today }
          end
        end
      end
    end
    switch_offs
  end

  def switch_offs_by_date(recalculate=true)
    start_date = start_of_current_billing_interval
    if recalculate
      recalculate_costs_and_switch_offs(end_of_billing_interval(Date.current + 1.month))
    end
    switch_offs = switch_off_details(start_date, false)
    results = {}
    return results if switch_offs == nil || switch_offs.empty?

    switch_offs.each do |group, instances|
      instances.each do |instance_type, off|
        next if off == nil || off == {}
        off.each do |days, number|
          date = (start_date + days.days).to_s
          if !results.has_key?(date)
            results[date] = {group => {instance_type => number}}
          elsif !results[date].has_key?(group)
            results[date][group] = {instance_type => number}
          else
            results[date][group][instance_type] = number
          end
        end
      end
    end
    results
  end

  def historic_cycle_details
    if !@details
      @details = []
      cycles = active_billing_cycles.select { |date| date <= Date.current }
      last_index = cycles.length - 1
      current = false
      cycles.each_with_index do |start_date, index|
        if index < last_index
          end_date = cycles[index + 1] - 1.day
        else
          end_date = end_of_billing_interval(start_date)
          current = true if Date.current >= start_date && Date.current <= end_date
        end
        # costs between dates does not include end date, 
        # so need to add another day
        if current
          costs = cost_breakdown(start_date, end_date, nil, true)
          cost = costs.reduce(0.0) do |sum, details|
            costs = details[1]
            sum + (costs[:total] ? costs[:total] : costs[:forecast_total])
          end
        else
          cost = costs_between_dates(start_date, end_date + 1.day).to_i
        end
        cycle_details = { start: start_date, end: end_date,
                          cost: cost,
                          current: current,
                          estimate: !latest_cost_log_date || end_date > latest_cost_log_date
                        }
        if current
          cycle_details[:costs_so_far] = costs_between_dates(start_date, Date.current).to_i
          cycle_details[:starting_balance] = remaining_balance(start_date)
          cycle_details[:starting_budget] = budget_on_date(start_date)
        end
        @details << cycle_details
      end
      @details.reverse!
    end
    @details
  end

  def billing_date
    policy = @project.budget_policies.where("effective_at <= ?", Date.current).last
    case policy.cycle_interval
    when 'monthly'
      '1st of the month'
    when 'weekly'
      "Every #{@project.start_date.strftime("%A")}"
    when 'custom'
      "Every #{policy.days} days"
    end
  end

  def cumulative_change_request_costs(temp_change_request)
    start_date = start_of_billing_interval(Date.current)
    end_date = end_of_billing_interval(start_date)
    costs = cost_breakdown(start_date, end_date, temp_change_request, true)
    return costs, chart_cumulative_costs(start_date, end_date, temp_change_request, costs)
  end

  def change_request_goes_over_budget?(change_request)
    start_date = start_of_billing_interval(Date.current)
    end_date = end_of_billing_interval(start_date)
    costs = cost_breakdown(start_date, end_date, change_request, true)
    end_costs = costs.to_a.last[1]
    end_budget = end_costs[:forecast_budget] ? end_costs[:forecast_budget] : end_costs[:budget]
    end_budget < 0
  end

  # For costs breakdown form
  def date_limit
    limit = start_of_current_billing_interval + 3.months
    limt = @project.archived_date if @project.archived_date
    end_of_billing_interval(limit)
  end

  def minimum_date
    active_billing_cycles.first
  end
end
