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
        MonitorJob.perform_late(project.id)
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
        MonitorJob.perform_later(p.id)
      end
    end
  end

  namespace :budget_switch_off_schedule do
    desc "Show over budget switch off schedules for all active projects"
    task :all, [:slack, :text] => :environment do |task, args|
      Project.active.each do |project|
        begin
        rescue StandardError => e
          puts "Error determining over budget switch offs for #{project.name}: #{e.message}"
          next
        end
        fork do
          Rake::Task['projects:budget_switch_off_schedule:by_project'].invoke(project.name,args[:slack],args[:text])
          Rake::Task['projects:budget_switch_off_schedule:by_project'].reenable
        end
      end
    end

    desc "Show over budget switch off schedule for a given project"
    task :by_project, [:project, :slack, :text] => :environment do |task, args|
      project = Project.find_by(name: args[:project])
      if !project
        puts "No project found with that name"
      else
        begin
          msg = project.budget_switch_off_schedule(args["slack"] == "true")
          puts msg if args["text"] == "true"
        rescue StandardError => e
          puts "Error determining over budget switch offs for #{project.name}: #{e.message}"
        end
      end
    end
  end
  
  namespace :budget_switch_offs do
    desc "Carry out any over budget scheduled switch offs for all active projects"
    task :all, [:slack, :text]  => :environment do |task, args|
      Project.active.each do |project|
        begin
        rescue Errno::ENOENT
          puts "No config file found for project #{project.name}"
          next
        end
        fork do
          Rake::Task['projects:budget_switch_offs:by_project'].invoke(project.name,args[:slack],args[:text])
          Rake::Task['projects:budget_switch_offs:by_project'].reenable
        end
      end
    end

    desc "Carry out any over budget switch offs for a given project"
    task :by_project, [:project, :slack, :text] do |task, args|
      project = Project.find_by(name: args[:project])
      if !project
        puts "No project found with that name"
      else
        begin
          msg = project.perform_budget_switch_offs(args[:slack] == "true")
          puts msg if args[:text] == "true"
        rescue Errno::ENOENT
          puts "No config file found for project #{project.name}"
        end
      end
    end
  end
end
