require_relative 'flight_hub_communicator'
require_relative '../models/hub_balance'
require_relative '../models/project'

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
        request_log = @flight_hub_communicator.move_funds(
          balance.to_i,
          "receive",
          "Budget for continuous project"
        )
        @project.send_slack_message(request_log.description)
        if request_log.status == "completed"
          balance = @flight_hub_communicator.check_balance # Should now be 0
          new_balance = @project.hub_balances.create(amount: balance, date: Date.current)
          @project.send_slack_message(new_balance.description)
          # amount should be existing budget + new amount
          create_cycle_budget(request_log.amount)
        end
      end
    rescue FlightHubApiError => error
      msg = "Unable to check Hub Balance for project #{@project.name}: #{error}" 
    end
  end

  # TODO: add validaton that is first day of cycle/ project end date, and has not already
  # been successfully run (i.e. transfer requests already completed)
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
  # TODO: add validaton that is first day of cycle, and has not already
  # been successfully run (i.e. transfer requests already completed)
  def check_out_cycle_budget
    # For continuous projects, we don't request at start of cycle, 
    # but whenever hub dept receives more compute units.
    return if @project.continuous_budget?
    return if @project.end_date && Date.current >= @project.end_date

    requested_budget = @costs_plotter.required_budget_for_cycle(Date.current).to_i

    if requested_budget > 0
      request_log = @flight_hub_communicator.move_funds(
        requested_budget,
        "receive",
        "Budget for current billing cycle",
      )
      @project.send_slack_message(request_log.description)
      check_and_update_hub_balance
    elsif requested_budget < 0
      # What to do in this situation?
    end
    request_log
  end

  def create_cycle_budget(amount)
    # Expiry date is the first day it no longer applies.
    if @project.continuous_budget?
      expiry = @project.end_date
    else
      expiry = @costs_plotter.end_of_billing_interval(Date.current) + 1.day
      expiry = [expiry, @project.end_date].min if @project.end_date
    end
    budget = @project.budgets.create(
      amount: amount,
      effective_at: Date.current,
      expiry_date: expiry
    )
    if !budget.valid?
      msg = "Unable to save budget for project *#{project.name}*: #{budget.errors.full_messages.join("; ") }"
      @project.send_slack_message()
    end
  end

  # TODO if try to check out and Hub does not have enough, kill all compute nodes.
  # Perhaps by setting budget/ balance to zero and running over budget switch offs

  def check_and_manage_funds
    if @project.continuous_budget?
      check_and_update_hub_balance
    elsif @costs_plotter.active_billing_cycles.include?(Date.current)
      sent = send_back_unused_compute_units
      if Date.current == @project.start_date || (sent && sent.valid? && sent.status == "completed")
        result = check_out_cycle_budget
        if result.status == "completed"
          create_cycle_budget(result.amount)
        end
      else
        msg = "Funds not requested from Hub for project *#{@project.name}*, as sending back to Hub failed."
        @project.send_slack_message(msg)
      end
    end
    
    if @project.end_date && @project.end_date == Date.current
      # send back remaining c.u.s
      send_back_unused_compute_units
    end
  end

  # Make this more robust
  def managed_this_cycle?
    @project.funds_transfer_requests.completed.where(date: Date.current).exist?
  end
end
