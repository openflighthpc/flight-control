require_relative "../../app/models/application_record"
require_relative "../../app/models/project"
require_relative "../../app/models/cost_log"


namespace :daily_reports do
  namespace :generate do
    task :all, [:rerun, :slack, :text, :verbose] => :environment do |task, args|
      Project.active.each do |project|
        generate_daily_report(project, Project::DEFAULT_COSTS_DATE, args["rerun"] == "true",
                              args["slack"], args["text"] == "true",
                              args["verbose"] == "true")
      end
    end

    task :by_project, [:project, :date, :rerun, :slack, :text, :verbose] => :environment do |task, args|
      project = Project.find_by(name: args["project"])
      if !project
        puts "No project found with that name"
      else
        if !args["date"] || args["date"] == "latest"
          date = Project::DEFAULT_COSTS_DATE
        else
          date = Date.parse(args["date"])
        end
          generate_daily_report(project, date, args["rerun"] == "true",
                                args["slack"], args["text"] == "true",
                                args["verbose"] == "true")
      end
    end
  end
end

def generate_daily_report(project, date, rerun, slack, text, verbose)
  begin
    project.daily_report(date, rerun, slack, text, verbose)
    puts
  rescue AzureApiError, AwsSdkError => e
    error = <<~MSG
    Generation of cost logs for project *#{project.name}* stopped due to error:
    #{e}
    MSG

    error << "\n#{"_" * 50}"
    puts error.gsub("*", "")
  end
end
