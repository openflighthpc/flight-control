require_relative "../../app/models/application_record"
require_relative "../../app/models/project"
require_relative "../../app/models/cost_log"

namespace :daily_reports do
  namespace :generate do
    desc "Generate daily reports for all active projects"
    task :all, [:date, :slack, :text, :rerun, :verbose] => :environment do |task, args|
      arguments = args.to_h
      Project.active.pluck(:name).each do |project|
        arguments[:project] = project
        # In an ideal world these would be background jobs, but to do that
        # will require an external queuing system such as redis, as otherwise
        # jobs stored in memory and lost when rake ends.
        fork do
          Rake::Task['daily_reports:generate:by_project'].execute(arguments)
          exit
        end
      end
      Process.waitall
    end

    desc "Generate daily report for one project"
    multitask :by_project, [:project, :date, :slack, :text, :rerun, :verbose] => :environment do |task, args|
      # When called directly, args use strings keys. But when called from the
      # all task using execute, it uses symbol keys.
      args = args.to_h.stringify_keys
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
                                args["slack"] == "true", args["text"] == "true",
                                args["verbose"] == "true")
        rescue AzureApiError, AwsSdkError => e
          error = <<~MSG
          Generation of daily report for project *#{project.name}* stopped due to error:
          #{e}
          MSG

          project.send_slack_message(error) if args["slack"] == "true"
          error << "\n#{"_" * 50}"
          puts error.gsub("*", "")
        end
      end
    end
  end
end
