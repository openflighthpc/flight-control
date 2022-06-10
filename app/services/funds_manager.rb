require_relative 'flight_hub_communicator'
require_relative '../models/balance'
require_relative '../models/project'

class FundsManager
  def initialize(project)
    @project = project
    @flight_hub_communicator = FlightHubCommunicator.new(project)
    @costs_plotter = project.costs_plotter
  end

  def check_and_update_balance
    balance =
    begin
      @flight_hub_communicator.check_balance
    rescue FlightHubApiError => error
      # add better error handling.
      return "Unable to check balance: #{error}"
    end
    return balance
    current_balance = @project.current_balance.amount
    if current_balance != balance
      new_balance = @project.balances.build(amount: balance, effective_at: Date.today)
      if new_balance.save
        "Balance updated"
      else
        "Unable to save balance: #{new_balance.errors.full_messages.join("; ")}"
      end
    end
  end

  # For now assume only run on first day of cycle
  def send_back_unused_compute_units
    return if Date.today <= @project.start_date # Don't attempt on first cycle

    start_of_last_cycle = @costs_plotter.start_of_billing_interval(Date.parse("2022/05/01"))
    end_of_last_cycle = @costs_plotter.end_of_billing_interval(start_of_last_cycle)
    costs = @costs_plotter.costs_between_dates(start_of_last_cycle, end_of_last_cycle + 1.day)
    starting_budget = @costs_plotter.budget_on_date(start_of_last_cycle)
    remaining = starting_budget - costs
    if remaining > 0
      begin
        result = @flight_hub_communicator.move_funds(
          remaining.to_i,
          "send",
          "Unused compute units at end of billing cycle",
          "Control"
        )
        if result[:success]
          # update/ create a log
        else
          # error handling
          puts result[:details]
        end
      rescue FlightHubApiError => error
        # add appropriate error handling
        puts error.error_messages.full_messages.join("; ")
      end
    elsif remaining < 0
      # how to handle this? Reduce next cycle's budget? Try to check the shortfall out?
      # What if dept doesn't have enough?
    end
  end

  # For now assume only run on first day of cycle
  def check_out_cycle_budget
    return if @project.end_date && Date.today >= @project.end_date

    # For some budget policies we need balance, for others we don't
    check_and_update_balance
    requested_budget = @costs_plotter.budget_on_date(Date.parse("2022/05/01")).to_i

    if requested_budget > 0
      begin
        result = @flight_hub_communicator.move_funds(
          requested_budget,
          "receive",
          "Budget for current billing cycle",
          "Control"
        )
        if result[:success]
          # update/ create a log
        else
          # error handling
          puts result[:details]
        end
      rescue FlightHubApiError => error
        # add appropriate error handling
        puts error.error_messages.full_messages.join("; ")
      end
    elsif remaining < 0
      # how to handle this? Reduce next cycle's budget? Try to check the shortfall out?
      # What if dept doesn't have enough?
    end
  end

end
