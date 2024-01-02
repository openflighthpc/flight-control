class ProjectDecorator < Draper::Decorator
  delegate_all

  def billing_history
    @billing_history ||= costs_plotter.historic_cycle_details
  end

  def billing_history_costs
    billing_history.map do |cycle|
      cycle[:cost]
    end
  end

  def billing_history_dates
    billing_history.map do |cycle|
      pretty_date(cycle[:end] + 1.day)
    end
  end

  def billing_history_tooltips
    billing_history.map do |cycle|
      [
        "#{pretty_date(cycle[:start])} - #{pretty_date(cycle[:end])}",
        "",
        "Total cost: #{cycle[:cost].to_i}cu",
        "",
        "Click to view costs breakdown",
        "for this billing cycle",
      ]
    end
  end

  private

  def pretty_date(date)
    date.strftime("#{date.day.ordinalize} %b")
  end
end
