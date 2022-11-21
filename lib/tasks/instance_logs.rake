namespace :instance_logs do
  namespace :record do
    desc "Record instance logs for all active projects"
    task :all, [:rerun, :verbose] => :environment do |task, args|
      rerun = args[:rerun] == "true"
      verbose = args[:verbose] == "true"
      Project.active.pluck(:id).each { |project_id| RecordInstanceLogsJob.perform_later(project_id, rerun, verbose) }
    end

    desc "Record instance logs for an individual project"
    task :by_project, [:project, :rerun, :verbose] => :environment do |task, args|
      project = Project.find_by(name: args[:project])
      if !project
        puts "No project found with the name #{args[:project]}"
      else
        RecordInstanceLogsJob.perform_later(project.id, args[:rerun] == "true", args[:verbose] == "true")
      end
    end
  end
end
