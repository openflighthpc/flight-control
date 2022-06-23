class CostCalculator

  attr_reader :total

  def initialize
    @total = 0.0
    @actual_costs = []
    @forecast_costs = []
  end

  def reset
    @total = 0.0
  end

  def add_cost_to_total(cost)
    @total += (cost || 0.0)
  end

  def append_total_to_array(is_actual:)
    if is_actual
      @actual_costs << @total
      @forecast_costs << nil
    else
      @actual_costs << nil
      @forecast_costs << @total
    end
  end

  def forecast_length
    @forecast_costs.length
  end

  def set_first_forecast
    @forecast_costs[-1] = @total
  end

end