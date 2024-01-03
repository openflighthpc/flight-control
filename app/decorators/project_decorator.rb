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
      date = pretty_date(billing_date(cycle))
      cycle[:current] ? [date, "(forecast)"] : date
    end
  end

  def billing_chart_dates(year)
    billing_history.select { |cycle| billing_date(cycle).year == year }
  end

  def billing_chart_data(year)
    billing_chart_dates(year).map { |cycle| { x: billing_date(cycle), y: cycle[:cost] } }
  end

  def billing_history_tooltips(year)
    billing_chart_dates(year).map do |cycle|
      tooltip = ["#{pretty_date(cycle[:start])} - #{pretty_date(cycle[:end])}", ""]
      if cycle[:current]
        tooltip << "Cost so far: #{cycle[:costs_so_far]}cu" << ""
      end
      tooltip << "#{cycle[:estimate] ? "Estimated t" : "T"}otal cost: #{cycle[:cost].to_i}cu" << ""
      tooltip << "Click to view costs breakdown" << "for this billing cycle"
      tooltip
    end
  end

  private

  def pretty_date(date)
    date.strftime("#{date.day.ordinalize} %b")
  end

  def billing_date(cycle)
    cycle[:end] + 1.day
  end
end