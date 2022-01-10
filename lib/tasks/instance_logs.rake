require_relative "../../app/models/application_record"
require_relative "../../app/models/project"
require_relative "../../app/models/instance_log"

namespace :instance_logs do
  namespace :record do
    task :all, [:rerun, :verbose] => :environment do |task, args|
      Project.active.each do |project|
        record_instance_logs(project, args["rerun"] == "true", args["verbose"] == "true")
      end
    end

    task :by_project, [:project, :rerun, :verbose] => :environment do |task, args|
      project = Project.find_by(name: args["project"])
      if !project
        puts "No project found with that name"
      else
        record_instance_logs(project, args["rerun"] == "true", args["verbose"] == "true")
      end
    end
  end
end

def record_instance_logs(project, rerun, verbose)
  begin
    print "Project #{project.name}: "
    print  project.record_instance_logs(rerun, verbose)
    puts
  rescue AzureApiError, AwsSdkError => e
    error = <<~MSG
    Generation of instance logs for project *#{project.name}* stopped due to error:
    #{e}
    MSG

    error << "\n#{"_" * 50}"
    puts error.gsub("*", "")
  end
end
