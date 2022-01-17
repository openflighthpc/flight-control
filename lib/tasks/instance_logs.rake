require_relative "../../app/models/application_record"
require_relative "../../app/models/project"
require_relative "../../app/models/instance_log"

namespace :instance_logs do
  namespace :record do
    desc "Record instance logs for all active projects"
    task :all, [:rerun, :verbose] => :environment do |task, args|
      arguments = args.to_h
      Project.active.pluck(:name).each do |project|
        arguments[:project] = project
        # In an ideal world these would be background jobs, but to do that
        # will require an external queuing system such as redis, as otherwise
        # jobs stored in memory and lost when rake ends.
        fork do
          Rake::Task['instance_logs:record:by_project'].execute(arguments)
          exit
        end
      end
      Process.waitall
    end

    desc "Record instance logs for an individual project"
    multitask :by_project, [:project, :rerun, :verbose] => :environment do |task, args|
      # When called directly, args use strings keys. But when called from the
      # all task using execute, it uses symbol keys.
      args = args.to_h.stringify_keys
      project = Project.find_by(name: args["project"])
      if !project
        puts "No project found with the name #{args["project"]}"
      else
        begin
          msg = "Project #{project.name}: "
          msg << project.record_instance_logs(args["rerun"] == "true", args["verbose"] == "true")
          puts msg
        rescue AzureApiError, AwsSdkError => e
          error = <<~MSG
          Generation of instance logs for project *#{project.name}* stopped due to error:
          #{e}
          MSG
       
          error << "\n#{"_" * 50}"
          puts error.gsub("*", "")
        end
      end
    end
  end
end
