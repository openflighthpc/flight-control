class ProjectDecorator < Draper::Decorator
  delegate_all

  def billing_history
    costs_plotter.historic_cycle_details
  end

  def billing_dates
    billing_history.map do |cycle|
      pretty_date(cycle[:end] + 1.day)
    end
  end

  def pretty_date(date)
    date.strftime("#{date.day.ordinalize} %b")
  end
end
