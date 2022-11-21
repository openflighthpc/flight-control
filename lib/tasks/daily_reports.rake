namespace :daily_reports do
  namespace :generate do
    desc "Generate daily reports for all active projects"
    task :all, [:date, :slack, :text, :rerun, :verbose] => :environment do |task, args|
      date = determine_date(args[:date])
      args = truthify_args(args)
      Project.active.pluck(:id).each do |project_id|
        DailyReportJob.perform_later(project_id, date, args[:rerun], args[:slack],
                                     args[:text], args[:verbose])
      end
    end

    desc "Generate daily report for one project"
    task :by_project, [:project, :date, :slack, :text, :rerun, :verbose] => :environment do |task, args|
      args = truthify_args(args)
      project = Project.find_by(name: args[:project])
      if !project
        puts "No project found with that name"
      else
        date = determine_date(args[:date])
        DailyReportJob.perform_later(project.id, date, args[:rerun], args[:slack],
                                     args[:text], args[:verbose])
      end
    end
  end
end

def determine_date(date_string)
  if !date_string || date_string == "latest"
    Project::DEFAULT_COSTS_DATE
  else
    Date.parse(date_string)
  end
end

def truthify_args(args)
  args.tap do |h|
    args.each do |k, v|
      unless [:project, :date].include?(k)
        h[k] = v == "true"
      end
    end
  end
end
