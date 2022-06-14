require_relative 'flight_hub_communicator'
require_relative '../models/hub_balance'
require_relative '../models/project'

class FundsManager
  def initialize(project)
    @project = project
    @flight_hub_communicator = FlightHubCommunicator.new(project)
    @costs_plotter = project.costs_plotter
  end

  # For continuous projects, we should request units from Hub as soon
  # as they are seen (e.g. if hub has any c.u.s we request the whole amount).
  # If we used message queues this could be event driven, e.g. Hub broadcasts balance,
  # control reads and reacts by requesting the c.u.s
  def check_and_update_hub_balance
    balance = @flight_hub_communicator.check_balance
    current_balance = @project.current_hub_balance.amount
    if current_balance != balance
      new_balance = @project.hub_balances.build(amount: balance, effective_at: Date.parse("2022/05/01"))
      if new_balance.save
        "Balance updated"
      else
        "Unable to save balance: #{new_balance.errors.full_messages.join("; ")}"
      end
    end
  end

  # Sending/ receiving c.u.s should probably update balance. And budget?

  # For now assume only run on first day of cycle
  def send_back_unused_compute_units
    return if @project.continuous?
    return if Date.today <= @project.start_date # Don't attempt on first cycle

    start_of_last_cycle = @costs_plotter.start_of_billing_interval(Date.parse("2022/05/01"))
    end_of_last_cycle = @costs_plotter.end_of_billing_interval(start_of_last_cycle)
    costs = @costs_plotter.costs_between_dates(start_of_last_cycle, end_of_last_cycle + 1.day)
    starting_budget = @costs_plotter.budget_on_date(start_of_last_cycle)
    remaining = starting_budget - costs
    if remaining > 0
      request_log = @flight_hub_communicator.move_funds(
          remaining.to_i,
          "send",
          "Unused compute units at end of billing cycle"
        )
      @project.send_slack_message(request_log.description)
    elsif remaining < 0 # Gone over budget. For now just send a slack message
      msg = "*Warning* project *#{@project.name} has gone over budget"
      msg << "\n Compute units have not been transfered to/from Flight Hub for this cycle"
      @project.send_slack_message(msg)
    end
  end

  # For now assume only run on first day of cycle
  def check_out_cycle_budget
    return if @project.continuous?
    return if @project.end_date && Date.today >= @project.end_date

    # For some budget policies we need balance, for others we don't
    check_and_update_hub_balance
    requested_budget = @costs_plotter.required_budget_for_cycle(Date.parse("2022/05/01")).to_i

    if requested_budget > 0
      request_log = @flight_hub_communicator.move_funds(
        requested_budget,
        "receive",
        "Budget for current billing cycle",
      )
      @project.send_slack_message(request_log.description)
    elsif requested_budget < 0
      # What to do in this situation?
    end
  end

  # TODO if try to check out and Hub does not have enough, kill all compute nodes.
  # Perhaps by setting budget/ balance to zero and running over budget switch offs

  def start_of_cycle_actions
    send_back_unused_compute_units
    check_out_cycle_budget
  end
end
