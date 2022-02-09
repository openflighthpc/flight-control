module Weekdays
  DAYSOFWEEK = %w[Mon Tue Wed Thu Fri Sat Sun]

  # Weekdays are stored as a 7 digit integer, saved as a string to retain leading zeroes. 
  # First digit represents Monday, last Sunday. If 1 include that day, if 0 do not.
  def named_weekdays
    return nil if !weekdays
    
    weekdays.split('').map.with_index {|digit, index| DAYSOFWEEK[index] if digit == "1"}.compact
  end

  def formatted_days
    return nil if !weekdays

    if weekdays == "1111111"
      "Every day"
    elsif weekdays == "1111100"
      "Mon - Fri"
    elsif weekdays == "0000011"
      "Weekends"
    else
      named_weekdays.join(", ")
    end
  end

  def seven_days
    errors.add(:weekdays, "must include entry for each day of week") if weekdays.length < 7
  end

  def at_least_one_day
    errors.add(:weekdays, "must include at least 1 day selected") if !weekdays.include?("1")
  end
end
