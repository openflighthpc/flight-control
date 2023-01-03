namespace :cost_logs do
  namespace :record do
    desc "Record cost logs for all active projects"
    task :all, [:rerun, :text, :verbose] => :environment do |task, args|
      date = Project::DEFAULT_COSTS_DATE
      args = TaskArgsHelper.truthify_args(args)
      Project.active.pluck(:id).each do |project_id|
        RecordCostLogsJob.perform_later(project_id, date, args[:rerun],
                                        args[:text], args[:verbose])
      end
    end

    desc "Record cost logs for one project"
    task :by_project, [:project, :date, :rerun, :text, :verbose] => :environment do |task, args|
      project = Project.find_by(name: args[:project])
      if !project
        puts "No project found with that name"
      else
        date = TaskArgsHelper.determine_date(args[:date])
        args = TaskArgsHelper.truthify_args(args)
        RecordCostLogsJob.perform_later(project.id, date, args[:rerun],
                                        args[:text], args[:verbose])
      end
    end

    desc 'Record logs for a date range, for one project'
    task :range, [:project, :start, :end, :rerun, :text, :verbose] => :environment do |task, args|
      project = Project.find_by(name: args[:project])
      if !project
        puts "No project found with that name"
      else
        start_date = Date.parse(args[:start])
        end_date = Date.parse(args[:end])
      end
      args = TaskArgsHelper.truthify_args(args)
      RecordCostLogsRangeJob.perform_later(project.id, start_date, end_date,
                                           args[:rerun], args[:text],
                                           args[:verbose])
    end
  end
end
