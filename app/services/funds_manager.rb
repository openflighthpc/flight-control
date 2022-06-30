class FundsManager
  def initialize(project)
    @project = project
    @flight_hub_communicator = FlightHubCommunicator.new(project)
    @costs_plotter = project.costs_plotter
  end

  # For continuous projects, we request units from Hub as soon
  # as they are seen (e.g. if hub has any c.u.s we request the whole amount).
  # If we used message queues this could be event driven, e.g. Hub broadcasts balance,
  # control reads and reacts by requesting the c.u.s
  def check_and_update_hub_balance
    return if @project.end_date && Date.current >= @project.end_date

    begin
      balance = @flight_hub_communicator.check_balance
      current_balance = @project.current_hub_balance
      if !current_balance || current_balance.amount != balance
        new_balance = @project.hub_balances.create(amount: balance, date: Date.current)
        @project.send_slack_message(new_balance.description)
      end
      if balance > 0 && @project.continuous_budget?
        check_out_and_update_continuous(balance.to_i)
      end
    rescue FlightHubApiError => error
      msg = "Unable to check Hub Balance for project #{@project.name}: #{error}"
      @project.send_slack_message(msg)
    end
  end

  def check_and_manage_funds
    if @project.end_date && @project.end_date == Date.current
      send_back_unused_compute_units
      create_budget(0, true) if !already_have_budget?
      return
    end

    # For continuous projects we retrieve any c.u. added to a department as
    # soon as this is detected, and we don't send any back until the project is
    # over.
    check_and_update_hub_balance

    if !@project.continuous_budget? && (Date.current == @project.start_date || @costs_plotter.active_billing_cycles.include?(Date.current)) &&
       !already_have_budget?
      sent = send_back_unused_compute_units
      if Date.current == @project.start_date || (sent && sent.valid? && sent.completed?)
        result = check_out_cycle_budget
        if result.completed?
          create_budget(result.amount)
        end
      else
        msg = "Funds not requested from Hub for project *#{@project.name}*, as sending back to Hub failed."
        @project.send_slack_message(msg)
      end
    end
  end

  def pending_budget_updates?
    !already_have_budget? &&
    (
      (!@project.continuous_budget? && @costs_plotter.active_billing_cycles.include?(Date.current)) ||
      @project.end_date && @project.end_date == Date.current ||
      @project.start_date == Date.current
    )
  end

  def update_end_budget
    end_date = @project.end_date
    end_budget = @project.budgets.find_by(final: true)
    return if !end_date && !end_budget

    if !end_date && end_budget
      # Basic handling if project is being restarted. But true handling
      # will require more work/thought, and perhaps involve manual updates.
      if end_budget.effective_at < Date.current
        end_budget.final = false
        end_budget.expiry_date ||= Date.current
        end_budget.save!
      else
        end_budget.delete
      end
    else
      if !end_budget
        create_budget(0, true, end_date)
      elsif end_budget && end_budget.effective_at != end_date
        end_budget.effective_at = end_date
        end_budget.save!
      end
    end
  end

  private

  def send_back_unused_compute_units
    end_of_project = @project.end_date && @project.end_date == Date.current
    # For continuous projects, we only send back at end of project
    return if @project.continuous_budget? && !end_of_project
    return if Date.current <= @project.start_date # Don't attempt on first cycle

    end_of_last_cycle = Date.current - 1.day
    start_of_last_cycle = @costs_plotter.start_of_billing_interval(Date.current - 1.day)
    costs = @costs_plotter.costs_between_dates(end_of_last_cycle, end_of_last_cycle + 1.day)
    # Budget can change during cycle, so determine what it was on start of the very last day
    remaining_start_of_last_day = @costs_plotter.budget_on_date(end_of_last_cycle)
    remaining = remaining_start_of_last_day - costs
    if remaining > 0
      request_log = @flight_hub_communicator.move_funds(
          remaining.to_i,
          "send",
          "Unused compute units at end of #{end_of_project ? "project" : "billing cycle"}"
        )
      @project.send_slack_message(request_log.description)
      check_and_update_hub_balance
    elsif remaining < 0 # Gone over budget. For now just send a slack message
      msg = "*Warning* project *#{@project.name}* has gone over budget"
      msg << "\n Compute units have not been transfered to/from Flight Hub"
      @project.send_slack_message(msg)
    end
    request_log
  end

  # Assume only run on first day of cycle
  def check_out_cycle_budget
    # For continuous projects, we don't request at start of cycle, 
    # but whenever hub dept receives more compute units.
    return if @project.continuous_budget?
    return if @project.end_date && Date.current >= @project.end_date

    required_budget = @costs_plotter.required_budget_for_current_cycle.to_i
    
    if required_budget > 0
      request_log = @flight_hub_communicator.move_funds(
        required_budget,
          "receive",
          "Budget for current billing cycle",
      )
      @project.send_slack_message(request_log.description)
      if request_log.not_enough_balance?
        insufficient_balance_handling(required_budget)
      else
        check_and_update_hub_balance
      end
    elsif required_budget < 0
      # This should only be reachable if a dynamic or rolling project goes
      # extremely over budget.
      msg = "Project #{@project.name} has a negative budget for this cyle. "
      msg << "No compute units have been requested from hub."
      @project.send_slack_message(msg)
    end
    request_log
  end

  def check_out_and_update_continuous(additional_compute_units)
    request_log = @flight_hub_communicator.move_funds(
      additional_compute_units,
        "receive",
        "Budget for continuous project"
      )
    @project.send_slack_message(request_log.description)

    if request_log.completed?
      # New budget is existing budget + additional received
      existing_budget = @project.budgets
        .where("effective_at <= ?", Date.current)
        .where("expiry_date IS NULL OR expiry_date > ?", Date.current).last
      existing_budget_amount = existing_budget ? existing_budget.amount : 0 
      create_budget(request_log.amount + existing_budget_amount)
      check_and_update_hub_balance
    end
  end

  def create_budget(amount, final=false, effective_at=Date.current)
    # Expiry date is the first day it no longer applies.
    if final
      expiry = nil
    elsif @project.continuous_budget?
      expiry = @project.end_date
    else
      expiry = @costs_plotter.end_of_billing_interval(Date.current) + 1.day
      expiry = [expiry, @project.end_date].min if @project.end_date
    end
    budget = @project.budgets.create!(
      amount: amount,
      effective_at: effective_at,
      expiry_date: expiry,
      final: final
    )
    if !budget.valid?
      msg = "Unable to save budget for project *#{@project.name}*: #{budget.errors.full_messages.join("; ") }"
      @project.send_slack_message(msg)
    else
      expire_previous_budget(budget) if @project.continuous_budget?
    end
  end

  # For continuous project the budgets are across cycles (and at any time),
  # so we expire them when a new one is created.
  def expire_previous_budget(latest_budget)
    previous = @project.budgets
                 .where("effective_at <= ?", Date.current)
                 .where("expiry_date IS NULL OR expiry_date >= ?", Date.current)
                 .where.not(id: latest_budget.id).last
    if previous
      previous.expiry_date = Date.current
      previous.save
    end
  end

  def insufficient_balance_handling(required)
    available_balance = @project.current_hub_balance
    available_balance = available_balance ? available_balance.amount : 0
    msg = "*WARNING:* Hub has insufficient compute units for latest cycle for project *#{@project.name}*"
    msg << "\n Running budget switch offs"
    @project.send_slack_message(msg)
    @project.perform_budget_switch_offs(true)
  end

  # This logic will become brittle if we start manually
  # creating budgets
  def already_have_budget?
    @project.budgets.where("expiry_date IS NULL OR expiry_date > ?", Date.current)
                    .find_by(effective_at: Date.current)
  end
end
