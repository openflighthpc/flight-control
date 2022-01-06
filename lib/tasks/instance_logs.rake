require_relative "../../app/models/application_record"
require_relative "../../app/models/project"
require_relative "../../app/models/instance_log"

namespace :instance_logs do
  namespace :record do
    task :all, [:rerun] => :environment do |task, args|
      Project.active.each { |project| record_logs(project, args["rerun"]) }
    end

    task :by_project, [:project, :rerun] => :environment do |task, args|
      project = Project.find_by(name: args["project"])
      if !project
        puts "No project found with that name"
      else
        record_logs(project, args["rerun"])
      end
    end
  end
end

def record_logs(project, rerun)
  begin
    puts "Project #{project.name}: #{project.record_instance_logs(rerun)}"
  rescue AzureApiError, AwsSdkError => e
    error = <<~MSG
    Generation of instance logs for project *#{project.name}* stopped due to error:
    #{e}
    MSG

    error << "\n#{"_" * 50}"
    puts error.gsub("*", "")
  end
end
