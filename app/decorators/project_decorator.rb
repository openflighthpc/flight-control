class ProjectDecorator < Draper::Decorator
  delegate_all

  def billing_history_years
    billing_history.map { |cycle| billing_date(cycle).year }
                   .uniq
  end

  def billing_chart_data
    billing_history_years.map do |year|
      [
        year,
        billing_history_by_year(year).map { |cycle| { x: billing_date(cycle), y: cycle[:cost] } }
      ]
    end.to_h
  end

  def billing_chart_tooltips
    billing_history_years.map do |year|
      [ year, billing_chart_tooltips_by_year(year) ]
    end.to_h
  end

  def billing_cycle_dates
    billing_history_years.map do |year|
      [
        year,
        billing_history_by_year(year).map { |cycle| { start: cycle[:start], end: cycle[:end] } }
      ]
    end.to_h
  end

  private

  def pretty_date(date)
    date.strftime("#{date.day.ordinalize} %b %Y")
  end

  def billing_date(cycle)
    cycle[:end] + 1.day
  end

  def billing_history
    @billing_history ||= costs_plotter.historic_cycle_details
  end

  def billing_history_by_year(year)
    billing_history.select { |cycle| billing_date(cycle).year == year }
  end

  def billing_chart_tooltips_by_year(year)
    billing_history_by_year(year).map do |cycle|
      tooltip = ["#{pretty_date(cycle[:start])} - #{pretty_date(cycle[:end])}", ""]
      if cycle[:current]
        tooltip << "Cost so far: #{cycle[:costs_so_far]}cu" << ""
      end
      tooltip << "#{cycle[:estimate] ? "Estimated t" : "T"}otal cost: #{cycle[:cost].to_i}cu" << ""
      tooltip << "Click to view costs breakdown" << "for this billing cycle"
      tooltip
    end
  end
end
