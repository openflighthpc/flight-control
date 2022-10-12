require_relative "../../app/models/application_record"
require_relative "../../app/models/project"
require_relative "../../app/models/cost_log"

namespace :cost_logs do
  namespace :record do
    desc "Record cost logs for all active projects"
    task :all, [:rerun, :text, :verbose] => :environment do |task, args|
      date = Project::DEFAULT_COSTS_DATE
      Project.active.each do |project|
        record_cost_logs(project, date, args["rerun"] == "true",
                         args["verbose"] == "true", args["text"] == "true")
      end
    end

    desc "Record cost logs for one project"
    task :by_project, [:project, :date, :rerun, :text, :verbose] => :environment do |task, args|
      project = Project.find_by(name: args["project"])
      if !project
        puts "No project found with that name"
      else
        if !args["date"] || args["date"] == "latest"
          date = Project::DEFAULT_COSTS_DATE
        else
          date = Date.parse(args["date"])
        end
        record_cost_logs(project, date, args["rerun"] == "true",
                         args["verbose"] == "true", args["text"] == "true")
      end
    end

    desc 'Record logs for a date range, for one project'
    task :range, [:project, :start, :end, :rerun, :text, :verbose] => :environment do |task, args|
      project = Project.find_by(name: args["project"])
      if !project
        puts "No project found with that name"
      else
        start_date = Date.parse(args["start"])
        end_date = Date.parse(args["end"])
      end
      record_cost_logs_for_range(project, start_date, end_date,
                                 args["rerun"] == "true",
                                 args["verbose"] == "true",
                                 args["text"] == "true")
    end
  end
end

def record_cost_logs(project, date, rerun, verbose, text)
  begin
    print "Project #{project.name}: " if text
    project.record_cost_logs(date, rerun, text, verbose)
    puts if text
  rescue AzureApiError, AwsSdkError => e
    error = <<~MSG
    Generation of cost logs for project *#{project.name}* stopped due to error:
    #{e}
    MSG

    error << "\n#{"_" * 50}"
    puts error.gsub("*", "")
  end
end

def record_cost_logs_for_range(project, start_date, end_date, rerun, verbose, text)
  begin
    print "Project #{project.name}: " if text
    print project.record_cost_logs_for_range(start_date, end_date, rerun, text, verbose)
    puts if text
  rescue AzureApiError, AwsSdkError => e
    error = <<~MSG
    Generation of cost logs for project *#{project.name}* stopped due to error:
    #{e}
    MSG

    error << "\n#{"_" * 50}"
    puts error.gsub("*", "")
  end
end
