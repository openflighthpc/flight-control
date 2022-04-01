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

  namespace :monitor do
    desc "Run CPU utilisation monitoring script for a single project"
    task :by_project, [:project] => :environment do |task, args|
      project = Project.find_by(name: args["project"])
      if !project
        puts "No project found with that name"
        return
      elsif !project.monitor_currently_active?
        puts "Monitor not currently active for this project"
      else
        project.check_and_switch_off_idle_nodes(true)
      end
    end

    desc "Run CPU utilisation monitoring script for all projects"
    task :all => :environment do |task|
      Project.active.each do |p|
        begin
          next if !p.monitor_currently_active?
        rescue Errno::ENOENT => e
          puts "Error monitoring #{p.name}: #{e.message}"
          next
        end
        fork do
          Rake::Task['projects:monitor:by_project'].invoke([p.name])
          Rake::Task['projects:monitor:by_project'].reenable
        end
      end
    end
  end
end
