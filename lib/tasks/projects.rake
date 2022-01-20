require_relative "../../app/models/application_record"
require_relative "../project_manager"

namespace :projects do
  desc "Create or update a project"
  task :manage => :environment do |task, args|
    ProjectManager.new.add_or_update_project
  end

  namespace :create_config do
    desc "Create config for all active projects"
    task :all, [:overwrite] => :environment do |task, args|
      overwrite = args["overwrite"] == "true"
      Project.active.each do |project|
        begin
          project.create_config_file(overwrite)
        rescue => error
          puts "Unable to create config file for #{project.name}: #{error}"
        end
        puts
      end
    end

    desc "Create config for one project"
    task :by_project, [:project, :overwrite] => :environment do |task, args|
      project = Project.find_by(name: args["project"])
      if !project
        puts "No project found with that name"
      else
        overwrite = args["overwrite"] == "true"
        begin
          project.create_config_file(overwrite)
        rescue => error
          puts "Unable to create config file for #{project.name}: #{error}"
        end
      end
    end
  end
end
