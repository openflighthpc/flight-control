module TaskArgsHelper
  def self.determine_date(date_string)
    if !date_string || date_string == "latest"
      Project::DEFAULT_COSTS_DATE
    else
      Date.parse(date_string)
    end
  end

  def self.truthify_args(args)
    args.tap do |h|
      args.each do |k, v|
        unless [:project, :date, :start, :end].include?(k)
          h[k] = v == "true"
        end
      end
    end
  end
end
