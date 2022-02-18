require_relative "../../app/models/application_record"
require_relative "../../app/models/project"
require_relative "../../app/models/change_request"

namespace :change_requests do
  desc "Check & update if pending change request completed for one project"
  task :by_project, [:project, :slack, :text] => :environment do |task, args|
    project = Project.find_by(name: args[:project])
    if !project
      puts "No project found with that name"
    else
      begin
        project.action_scheduled(args[:slack] == "true", args[:text] == "true")
      rescue Errno::ENOENT
        puts "No config file found for project #{project.name}"
      end
    end
  end

  task :all,[:slack, :text] => :environment do |task, args|
    Project.active.each do |project|
      begin
        project.action_scheduled(args[:slack] == "true", args[:text] == "true")
      rescue Errno::ENOENT
        puts "No config file found for project #{project.name}"
      end
    end
  end
end
