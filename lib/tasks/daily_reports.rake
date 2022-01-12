require_relative "../../app/models/application_record"
require_relative "../../app/models/project"
require_relative "../../app/models/cost_log"
require_relative "../../app/jobs/daily_report_job"

namespace :daily_reports do
  namespace :generate do
    task :all, [:rerun, :slack, :text, :verbose] => :environment do |task, args|
      arguments = args.to_h
      arguments[:date] = Project::DEFAULT_COSTS_DATE.to_s
      Project.active.pluck(:name).each do |project|
        arguments[:project] = project
        # In an ideal world these would be background jobs, but to do that
        # will require an external queuing system such as redis, as otherwise
        # jobs stored in memory and lost when rake ends.
        fork do
          Rake::Task['daily_reports:generate:by_project'].execute(arguments)
        end
      end
    end

    task :by_project, [:project, :date, :rerun, :slack, :text, :verbose] => :environment do |task, args|
      # When called directly, args use strings keys. But when called from the
      # all task using execute, it uses symbol keys.
      args = args.stringify_keys
      project = Project.find_by(name: args["project"])
      if !project
        puts "No project found with that name"
      else
        if !args["date"] || args["date"] == "latest"
          date = Project::DEFAULT_COSTS_DATE
        else
          date = Date.parse(args["date"])
        end
        begin
          project.daily_report(date, args["rerun"] == "true",
                                args["slack"], args["text"] == "true",
                                args["verbose"] == "true")
        rescue AzureApiError, AwsSdkError => e
          error = <<~MSG
          Generation of cost logs for project *#{project.name}* stopped due to error:
          #{e}
          MSG

          error << "\n#{"_" * 50}"
          puts error.gsub("*", "")
        end
      end
    end
  end
end
